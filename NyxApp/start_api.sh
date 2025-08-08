#!/bin/bash

# Nyx API Server Startup Script

echo "🤖 Starting Nyx API Server..."

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Install/upgrade requirements
echo "📥 Installing requirements..."
pip install -r api_requirements.txt

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "⚠️  No .env file found. Creating template..."
    cat > .env << EOF
# Nyx API Configuration
DISCORD_TOKEN=your_discord_bot_token_here
ANTHROPIC_API_KEY=your_anthropic_api_key_here
STORAGE_PATH=./nyxnotes
HOST=127.0.0.1
PORT=8000
EOF
    echo "📝 Please edit .env file with your API keys before running the server."
    echo "   You can start the server anyway for testing with mock data."
fi

# Start the server
echo "🚀 Starting Nyx API Server on http://localhost:8000"
echo "📚 API Documentation available at: http://localhost:8000/docs"
echo "🔄 Interactive API available at: http://localhost:8000/redoc"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

python api_server.py