# session_manager.py
import os
import json
import asyncio
import aiofiles
import shutil
from datetime import datetime, timezone
from typing import Dict, Any, Optional, List
import logging

STORAGE_PATH = os.getenv("STORAGE_PATH", "./nyxnotes")
RESIDENT_RECORDS = os.path.join(STORAGE_PATH, "resident_records")
SAVED_FOREVER_CHATS = os.path.join(RESIDENT_RECORDS, "saved_forever_chats")

os.makedirs(RESIDENT_RECORDS, exist_ok=True)
os.makedirs(SAVED_FOREVER_CHATS, exist_ok=True)

class SessionManager:
    """Manages chat sessions, archiving, and retrieval for all chat modes."""
    
    def __init__(self):
        self.storage_path = STORAGE_PATH
        self.resident_records = RESIDENT_RECORDS
        self.saved_forever_chats = SAVED_FOREVER_CHATS
        self._locks = {}
        self.logger = logging.getLogger("session_manager")
        
        # Active sessions tracking
        self.active_sessions = {}
        
        # Session metadata
        self.session_metadata_file = os.path.join(RESIDENT_RECORDS, "session_metadata.json")
        
        # Ensure directories exist
        os.makedirs(self.resident_records, exist_ok=True)
        os.makedirs(self.saved_forever_chats, exist_ok=True)
        
        # Initialize metadata
        asyncio.create_task(self._initialize_metadata())
    
    async def _initialize_metadata(self):
        """Initialize session metadata file if it doesn't exist."""
        if not os.path.exists(self.session_metadata_file):
            initial_metadata = {
                "sessions": {},
                "user_sessions": {},
                "last_updated": datetime.now(timezone.utc).isoformat()
            }
            await self._save_json(self.session_metadata_file, initial_metadata)
    
    def _get_lock(self, file_path: str):
        """Get or create a lock for a specific file."""
        if file_path not in self._locks:
            self._locks[file_path] = asyncio.Lock()
        return self._locks[file_path]
    
    async def _load_json(self, file_path: str) -> Dict:
        """Load JSON data from file with proper locking."""
        lock = self._get_lock(file_path)
        async with lock:
            if os.path.exists(file_path):
                try:
                    async with aiofiles.open(file_path, 'r', encoding='utf-8') as f:
                        data = await f.read()
                        if data.strip():
                            return json.loads(data)
                except Exception as e:
                    self.logger.error(f"Error loading {file_path}: {e}")
            return {}
    
    async def _save_json(self, file_path: str, data: Dict):
        """Save JSON data to file with atomic operations."""
        lock = self._get_lock(file_path)
        async with lock:
            try:
                os.makedirs(os.path.dirname(file_path), exist_ok=True)
                
                temp_file = file_path + '.tmp'
                async with aiofiles.open(temp_file, 'w', encoding='utf-8') as f:
                    await f.write(json.dumps(data, indent=2, ensure_ascii=False))
                
                # Atomic rename
                if os.path.exists(file_path):
                    backup_file = file_path + '.backup'
                    if os.path.exists(backup_file):
                        os.remove(backup_file)
                    os.rename(file_path, backup_file)
                
                os.rename(temp_file, file_path)
                
            except Exception as e:
                self.logger.error(f"Error saving {file_path}: {e}")
                # Restore backup if save failed
                backup_file = file_path + '.backup'
                if os.path.exists(backup_file) and not os.path.exists(file_path):
                    try:
                        os.rename(backup_file, file_path)
                        self.logger.info(f"Restored {file_path} from backup")
                    except Exception as restore_error:
                        self.logger.error(f"Failed to restore backup: {restore_error}")
    
    def generate_session_id(self, user_id: str, chat_mode: str) -> str:
        """Generate a unique session ID."""
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
        return f"{chat_mode}_{user_id}_{timestamp}"
    
    async def get_active_session(self, user_id: str, chat_mode: str) -> Optional[Dict]:
        """Get the current active session for a user in a specific chat mode."""
        session_key = f"{user_id}_{chat_mode}"
        
        if session_key in self.active_sessions:
            session_id = self.active_sessions[session_key]
            session_file = os.path.join(self.storage_path, f"session_{session_id}.json")
            
            if os.path.exists(session_file):
                return await self._load_json(session_file)
        
        # Create new session if none exists
        return await self.create_new_session(user_id, chat_mode)
    
    async def create_new_session(self, user_id: str, chat_mode: str) -> Dict:
        """Create a new chat session."""
        session_id = self.generate_session_id(user_id, chat_mode)
        session_key = f"{user_id}_{chat_mode}"
        
        # Archive current session if exists
        if session_key in self.active_sessions:
            old_session_id = self.active_sessions[session_key]
            await self._archive_session(old_session_id, user_id, chat_mode, auto_archive=True)
        
        # Create new session
        new_session = {
            "session_id": session_id,
            "user_id": user_id,
            "chat_mode": chat_mode,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "last_updated": datetime.now(timezone.utc).isoformat(),
            "messages": [],
            "metadata": {
                "message_count": 0,
                "is_archived": False,
                "is_saved_forever": False
            }
        }
        
        # Save session file
        session_file = os.path.join(self.storage_path, f"session_{session_id}.json")
        await self._save_json(session_file, new_session)
        
        # Update active sessions
        self.active_sessions[session_key] = session_id
        
        # Update metadata
        await self._update_session_metadata(session_id, user_id, chat_mode, "active")
        
        self.logger.info(f"Created new session {session_id} for user {user_id} in {chat_mode} mode")
        return new_session
    
    async def add_message_to_session(self, user_id: str, chat_mode: str, message: Dict):
        """Add a message to the current active session."""
        session = await self.get_active_session(user_id, chat_mode)
        
        if session:
            session["messages"].append({
                **message,
                "timestamp": datetime.now(timezone.utc).isoformat()
            })
            session["last_updated"] = datetime.now(timezone.utc).isoformat()
            session["metadata"]["message_count"] = len(session["messages"])
            
            # Save updated session
            session_file = os.path.join(self.storage_path, f"session_{session['session_id']}.json")
            await self._save_json(session_file, session)
            
            return session
        
        return None
    
    async def save_forever(self, user_id: str, chat_mode: str, session_name: Optional[str] = None) -> bool:
        """Save the current session forever to Resident Records."""
        session_key = f"{user_id}_{chat_mode}"
        
        if session_key not in self.active_sessions:
            self.logger.warning(f"No active session found for {user_id} in {chat_mode}")
            return False
        
        session_id = self.active_sessions[session_key]
        session_file = os.path.join(self.storage_path, f"session_{session_id}.json")
        
        if not os.path.exists(session_file):
            self.logger.error(f"Session file not found: {session_file}")
            return False
        
        # Load session data
        session_data = await self._load_json(session_file)
        
        # Generate archive name
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
        if session_name:
            archive_name = f"{session_name}_{timestamp}"
        else:
            archive_name = f"{chat_mode}_{user_id}_{timestamp}"
        
        # Create directories for saved session
        user_saved_dir = os.path.join(self.saved_forever_chats, str(user_id))
        mode_saved_dir = os.path.join(user_saved_dir, chat_mode)
        os.makedirs(mode_saved_dir, exist_ok=True)
        
        # Archive file paths
        archive_file = os.path.join(mode_saved_dir, f"{archive_name}.json")
        resident_file = os.path.join(self.resident_records, f"saved_{archive_name}.json")
        
        # Update session metadata
        session_data["metadata"]["is_saved_forever"] = True
        session_data["metadata"]["saved_at"] = datetime.now(timezone.utc).isoformat()
        session_data["metadata"]["archive_name"] = archive_name
        session_data["metadata"]["saved_by_user"] = True
        
        # Save to both locations
        await self._save_json(archive_file, session_data)
        await self._save_json(resident_file, session_data)
        
        # Update session metadata
        await self._update_session_metadata(session_id, user_id, chat_mode, "saved_forever", archive_name)
        
        # Create new session for continued chatting
        await self.create_new_session(user_id, chat_mode)
        
        self.logger.info(f"Session {session_id} saved forever as {archive_name}")
        return True
    
    async def _archive_session(self, session_id: str, user_id: str, chat_mode: str, auto_archive: bool = False):
        """Archive a session to Resident Records."""
        session_file = os.path.join(self.storage_path, f"session_{session_id}.json")
        
        if not os.path.exists(session_file):
            return
        
        # Load session data
        session_data = await self._load_json(session_file)
        
        # Skip if already archived
        if session_data.get("metadata", {}).get("is_archived"):
            return
        
        # Update metadata
        session_data["metadata"]["is_archived"] = True
        session_data["metadata"]["archived_at"] = datetime.now(timezone.utc).isoformat()
        session_data["metadata"]["auto_archived"] = auto_archive
        
        # Create archive directory
        user_archive_dir = os.path.join(self.resident_records, "auto_archives", str(user_id))
        os.makedirs(user_archive_dir, exist_ok=True)
        
        # Archive file path
        archive_file = os.path.join(user_archive_dir, f"archive_{session_id}.json")
        
        # Save archived session
        await self._save_json(archive_file, session_data)
        
        # Move original file to archives
        try:
            shutil.move(session_file, archive_file + ".original")
        except:
            pass
        
        # Update session metadata
        await self._update_session_metadata(session_id, user_id, chat_mode, "archived")
        
        self.logger.info(f"Session {session_id} archived {'automatically' if auto_archive else 'manually'}")
    
    async def _update_session_metadata(self, session_id: str, user_id: str, chat_mode: str, status: str, archive_name: Optional[str] = None):
        """Update the global session metadata."""
        metadata = await self._load_json(self.session_metadata_file)
        
        # Update session info
        metadata["sessions"][session_id] = {
            "user_id": user_id,
            "chat_mode": chat_mode,
            "status": status,
            "last_updated": datetime.now(timezone.utc).isoformat(),
            "archive_name": archive_name
        }
        
        # Update user sessions list
        if user_id not in metadata["user_sessions"]:
            metadata["user_sessions"][user_id] = []
        
        if session_id not in metadata["user_sessions"][user_id]:
            metadata["user_sessions"][user_id].append(session_id)
        
        metadata["last_updated"] = datetime.now(timezone.utc).isoformat()
        
        await self._save_json(self.session_metadata_file, metadata)
    
    async def get_saved_sessions(self, user_id: str, chat_mode: Optional[str] = None) -> List[Dict]:
        """Get list of saved sessions for a user."""
        saved_sessions = []
        
        user_saved_dir = os.path.join(self.saved_forever_chats, str(user_id))
        
        if not os.path.exists(user_saved_dir):
            return saved_sessions
        
        # Get sessions from specific mode or all modes
        if chat_mode:
            mode_dirs = [os.path.join(user_saved_dir, chat_mode)]
        else:
            mode_dirs = [os.path.join(user_saved_dir, d) for d in os.listdir(user_saved_dir) 
                        if os.path.isdir(os.path.join(user_saved_dir, d))]
        
        for mode_dir in mode_dirs:
            if not os.path.exists(mode_dir):
                continue
            
            for filename in os.listdir(mode_dir):
                if filename.endswith('.json'):
                    file_path = os.path.join(mode_dir, filename)
                    try:
                        session_data = await self._load_json(file_path)
                        saved_sessions.append({
                            "filename": filename,
                            "chat_mode": session_data.get("chat_mode"),
                            "created_at": session_data.get("created_at"),
                            "saved_at": session_data.get("metadata", {}).get("saved_at"),
                            "message_count": session_data.get("metadata", {}).get("message_count", 0),
                            "archive_name": session_data.get("metadata", {}).get("archive_name")
                        })
                    except Exception as e:
                        self.logger.error(f"Error loading saved session {file_path}: {e}")
        
        # Sort by saved date (newest first)
        saved_sessions.sort(key=lambda x: x.get("saved_at", ""), reverse=True)
        
        return saved_sessions
    
    async def load_saved_session(self, user_id: str, archive_name: str) -> Optional[Dict]:
        """Load a specific saved session."""
        user_saved_dir = os.path.join(self.saved_forever_chats, str(user_id))
        
        # Search for the session in all mode directories
        for mode_dir in os.listdir(user_saved_dir):
            mode_path = os.path.join(user_saved_dir, mode_dir)
            if os.path.isdir(mode_path):
                for filename in os.listdir(mode_path):
                    if archive_name in filename and filename.endswith('.json'):
                        file_path = os.path.join(mode_path, filename)
                        return await self._load_json(file_path)
        
        return None
    
    async def clear_session(self, user_id: str, chat_mode: str):
        """Clear the current session and start fresh."""
        session_key = f"{user_id}_{chat_mode}"
        
        # Archive current session if exists
        if session_key in self.active_sessions:
            session_id = self.active_sessions[session_key]
            await self._archive_session(session_id, user_id, chat_mode, auto_archive=True)
        
        # Create new session
        return await self.create_new_session(user_id, chat_mode)

# Singleton instance
session_manager = SessionManager()