import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'attachment_picker.dart';

/// Mockup color palette for Create Support Ticket form.
class TicketFormPalette {
  static const primaryRed = Color(0xFFD32F2F);
  static const textPrimary = Color(0xFF1A202C);
  static const textSecondary = Color(0xFF718096);
  static const border = Color(0xFFE2E8F0);
  static const white = Color(0xFFFFFFFF);
}

class CreateTicketSheet extends StatefulWidget {
  final String accessToken;
  final VoidCallback onCreated;

  const CreateTicketSheet({
    super.key,
    required this.accessToken,
    required this.onCreated,
  });

  static Future<void> show(
    BuildContext context, {
    required String accessToken,
    required VoidCallback onCreated,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) {
      return _showMobileSheet(context, accessToken: accessToken, onCreated: onCreated);
    }
    return _showDesktopDialog(context, accessToken: accessToken, onCreated: onCreated);
  }

  static Future<void> _showMobileSheet(
    BuildContext context, {
    required String accessToken,
    required VoidCallback onCreated,
  }) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) {
        final kb = MediaQuery.viewInsetsOf(ctx).bottom;
        final maxH = MediaQuery.sizeOf(ctx).height * 0.9;
        return Padding(
          padding: EdgeInsets.only(bottom: kb),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: TicketFormPalette.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: CreateTicketSheet(
                accessToken: accessToken,
                onCreated: onCreated,
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<void> _showDesktopDialog(
    BuildContext context, {
    required String accessToken,
    required VoidCallback onCreated,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => Dialog(
        backgroundColor: TicketFormPalette.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
          ),
          child: CreateTicketSheet(
            accessToken: accessToken,
            onCreated: onCreated,
          ),
        ),
      ),
    );
  }

  @override
  State<CreateTicketSheet> createState() => _CreateTicketSheetState();
}

class _CreateTicketSheetState extends State<CreateTicketSheet> {
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _priority = 'medium';
  PickedAttachment? _attachment;
  bool _submitting = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _isMobile => MediaQuery.sizeOf(context).width < 600;

  InputDecoration _fieldDecoration({
    Color borderColor = TicketFormPalette.border,
    String? hint,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        color: TicketFormPalette.textSecondary,
        fontSize: 14,
      ),
      filled: true,
      fillColor: TicketFormPalette.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
    );
  }

  Widget _label(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: TicketFormPalette.textPrimary,
          ),
          children: [
            TextSpan(text: text),
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: TicketFormPalette.primaryRed),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final picked = await pickAttachment();
      if (!mounted) return;
      if (picked != null) {
        setState(() => _attachment = picked);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick file: $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (_subjectCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject and description are required')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final uri = Uri.parse(ApiConfig.ticketsUrl);
      final token = widget.accessToken;

      if (_attachment != null) {
        final request = http.MultipartRequest('POST', uri);
        request.headers['Authorization'] = 'Bearer $token';
        request.fields['subject'] = _subjectCtrl.text.trim();
        request.fields['description'] = _descCtrl.text.trim();
        request.fields['priority'] = _priority;
        request.files.add(http.MultipartFile.fromBytes(
          'attachment',
          _attachment!.bytes,
          filename: _attachment!.name,
        ));
        final res = await request.send().timeout(const Duration(seconds: 30));
        if (!mounted) return;
        if (res.statusCode == 200 || res.statusCode == 201) {
          Navigator.pop(context);
          widget.onCreated();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ticket created successfully')),
          );
        } else {
          final body = await res.stream.bytesToString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed (${res.statusCode}): $body')),
          );
        }
      } else {
        final response = await http
            .post(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: json.encode({
                'subject': _subjectCtrl.text.trim(),
                'description': _descCtrl.text.trim(),
                'priority': _priority,
              }),
            )
            .timeout(const Duration(seconds: 30));
        if (!mounted) return;
        if (response.statusCode == 200 || response.statusCode == 201) {
          Navigator.pop(context);
          widget.onCreated();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ticket created successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${response.body}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Subject', required: true),
        TextField(
          controller: _subjectCtrl,
          style: GoogleFonts.inter(fontSize: 14, color: TicketFormPalette.textPrimary),
          decoration: _fieldDecoration(
            borderColor: TicketFormPalette.primaryRed,
            hint: 'Brief summary of your issue',
          ),
        ),
        const SizedBox(height: 16),
        _label('Description', required: true),
        TextField(
          controller: _descCtrl,
          maxLines: _isMobile ? 3 : 5,
          minLines: _isMobile ? 3 : 5,
          style: GoogleFonts.inter(fontSize: 14, color: TicketFormPalette.textPrimary),
          decoration: _fieldDecoration(
            hint: 'Provide detailed information about your request...',
          ),
        ),
        const SizedBox(height: 16),
        _label('Priority'),
        DropdownButtonFormField<String>(
          initialValue: _priority,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: TicketFormPalette.textSecondary),
          style: GoogleFonts.inter(fontSize: 14, color: TicketFormPalette.textPrimary),
          decoration: _fieldDecoration(),
          items: const [
            DropdownMenuItem(value: 'low', child: Text('Low')),
            DropdownMenuItem(value: 'medium', child: Text('Medium')),
            DropdownMenuItem(value: 'high', child: Text('High')),
            DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
          ],
          onChanged: _submitting ? null : (v) => setState(() => _priority = v ?? 'medium'),
        ),
        const SizedBox(height: 16),
        _label('Upload picture / file'),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _submitting ? null : _pickFile,
            borderRadius: BorderRadius.circular(24),
            child: CustomPaint(
              painter: _DashedBorderPainter(color: TicketFormPalette.border, radius: 24),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      _attachment != null
                          ? Icons.check_circle_outline
                          : Icons.add_photo_alternate_outlined,
                      size: 22,
                      color: _attachment != null
                          ? TicketFormPalette.primaryRed
                          : TicketFormPalette.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _attachment?.name ?? 'Tap to choose photo or document',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: _attachment != null
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: _attachment != null
                              ? TicketFormPalette.textPrimary
                              : TicketFormPalette.textSecondary,
                        ),
                      ),
                    ),
                    if (_attachment != null)
                      IconButton(
                        onPressed: _submitting
                            ? null
                            : () => setState(() => _attachment = null),
                        icon: const Icon(Icons.close, size: 18),
                        color: TicketFormPalette.textSecondary,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Remove file',
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_attachment != null) ...[
          const SizedBox(height: 12),
          _buildAttachmentPreview(),
        ],
      ],
    );
  }

  Widget _buildAttachmentPreview() {
    final file = _attachment!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TicketFormPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (file.isImage)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              child: Image.memory(
                file.bytes,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(20),
              child: Icon(
                Icons.insert_drive_file_outlined,
                size: 48,
                color: TicketFormPalette.textSecondary,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Icon(
                  file.isImage ? Icons.image_outlined : Icons.attach_file,
                  size: 18,
                  color: TicketFormPalette.primaryRed,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    file.name,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: TicketFormPalette.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(file.bytes.length / 1024).toStringAsFixed(1)} KB',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: TicketFormPalette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final cancelBtn = OutlinedButton(
      onPressed: _submitting ? null : () => Navigator.pop(context),
      style: OutlinedButton.styleFrom(
        foregroundColor: TicketFormPalette.textPrimary,
        side: const BorderSide(color: TicketFormPalette.border, width: 1.5),
        shape: const StadiumBorder(),
        padding: EdgeInsets.symmetric(
          horizontal: _isMobile ? 20 : 28,
          vertical: 14,
        ),
      ),
      child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
    );

    final createBtn = ElevatedButton(
      onPressed: _submitting ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: TicketFormPalette.primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const StadiumBorder(),
        padding: EdgeInsets.symmetric(
          horizontal: _isMobile ? 20 : 28,
          vertical: 14,
        ),
      ),
      child: _submitting
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text('Create Ticket',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
    );

    if (_isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: double.infinity, child: createBtn),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: cancelBtn),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        cancelBtn,
        const SizedBox(width: 12),
        createBtn,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hPad = _isMobile ? 20.0 : 28.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.maxHeight < double.infinity;

        final scrollBody = SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
          child: _buildFormFields(),
        );

        return SafeArea(
          top: _isMobile,
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (_isMobile)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: TicketFormPalette.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, _isMobile ? 16 : 24, hPad, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Support Ticket',
                            style: GoogleFonts.inter(
                              fontSize: _isMobile ? 18 : 22,
                              fontWeight: FontWeight.w800,
                              color: TicketFormPalette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fill in the details below to submit your request.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: TicketFormPalette.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _submitting ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: TicketFormPalette.textPrimary),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              if (bounded) Expanded(child: scrollBody) else scrollBody,
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(hPad, 12, hPad, _isMobile ? 20 : 24),
                decoration: const BoxDecoration(
                  color: TicketFormPalette.white,
                  border: Border(top: BorderSide(color: TicketFormPalette.border)),
                ),
                child: _buildFooter(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, this.radius = 24});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
