import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Optimized chat input widget that reduces unnecessary rebuilds
class OptimizedChatInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;
  final String hintText;
  final FocusNode? focusNode;
  final VoidCallback? onTap;

  const OptimizedChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.isLoading = false,
    this.hintText = 'Type a message...',
    this.focusNode,
    this.onTap,
  });

  @override
  State<OptimizedChatInput> createState() => _OptimizedChatInputState();
}

class _OptimizedChatInputState extends State<OptimizedChatInput> {
  late FocusNode _focusNode;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    widget.controller.addListener(_handleTextChange);
    _hasText = widget.controller.text.isNotEmpty;
  }

  void _handleTextChange() {
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleSubmit() {
    if (_hasText && !widget.isLoading) {
      widget.onSend();
    }
  }

  void _showTextOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.controller.text.isNotEmpty) ...[
              ListTile(
                leading: const Icon(Icons.select_all),
                title: const Text('Select All'),
                onTap: () {
                  Navigator.pop(context);
                  HapticFeedback.lightImpact();
                  widget.controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: widget.controller.text.length,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(context);
                  HapticFeedback.lightImpact();
                  Clipboard.setData(ClipboardData(text: widget.controller.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Text copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.clear),
                title: const Text('Clear'),
                onTap: () {
                  Navigator.pop(context);
                  HapticFeedback.lightImpact();
                  widget.controller.clear();
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.paste),
              title: const Text('Paste'),
              onTap: () async {
                Navigator.pop(context);
                HapticFeedback.lightImpact();
                final data = await Clipboard.getData('text/plain');
                if (data?.text != null) {
                  final currentText = widget.controller.text;
                  final selection = widget.controller.selection;
                  final newText = currentText.replaceRange(
                    selection.start,
                    selection.end,
                    data!.text!,
                  );
                  widget.controller.value = TextEditingValue(
                    text: newText,
                    selection: TextSelection.collapsed(
                      offset: selection.start + data.text!.length,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 56,
                maxHeight: 160,
              ),
              child: GestureDetector(
                onLongPress: () {
                  HapticFeedback.lightImpact();
                  _showTextOptions(context);
                },
                child: Scrollbar(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    minLines: 1,
                    scrollPhysics: const BouncingScrollPhysics(),
                    enabled: !widget.isLoading,
                    onSubmitted: (_) => _handleSubmit(),
                    onTap: widget.onTap,
                    textInputAction: TextInputAction.newline,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: widget.isLoading || !_hasText
                  ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3)
                  : Theme.of(context).colorScheme.secondary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.isLoading || !_hasText ? null : _handleSubmit,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.send,
                    size: 20,
                    color: widget.isLoading || !_hasText
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}