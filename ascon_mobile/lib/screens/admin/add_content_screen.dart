import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/events_view_model.dart';
import '../../viewmodels/dashboard_view_model.dart';

class AddContentScreen extends ConsumerStatefulWidget {
  final String type; // 'Event' or 'Programme'

  const AddContentScreen({super.key, required this.type});

  @override
  ConsumerState<AddContentScreen> createState() => _AddContentScreenState();
}

class _AddContentScreenState extends ConsumerState<AddContentScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  
  // Event Specific
  final TextEditingController _timeController = TextEditingController();
  DateTime? _selectedDate;
  String _eventType = "News";
  
  // Programme Specific
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _feeController = TextEditingController();

  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _selectedImage = image);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select an image")));
      return;
    }

    setState(() => _isSubmitting = true);

    String? error;
    
    if (widget.type == 'Event') {
      // ✅ Create Event
      error = await ref.read(eventsProvider.notifier).createEvent(
        title: _titleController.text,
        description: _descController.text,
        location: _locationController.text,
        time: _timeController.text,
        type: _eventType,
        date: _selectedDate ?? DateTime.now(),
        image: _selectedImage,
      );
    } else {
      // ✅ Create Programme
      error = await ref.read(eventsProvider.notifier).createProgramme(
        title: _titleController.text,
        description: _descController.text,
        location: _locationController.text,
        duration: _durationController.text,
        fee: _feeController.text,
        image: _selectedImage!,
      );
      
      // Refresh Dashboard to show new programme
      if (error == null) {
        ref.read(dashboardProvider.notifier).loadData(isRefresh: true);
      }
    }

    setState(() => _isSubmitting = false);

    if (error == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${widget.type} Created Successfully!")));
        Navigator.pop(context);
      }
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $error"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add ${widget.type}")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Image Picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[400]!),
                    image: _selectedImage != null 
                        ? DecorationImage(image: FileImage(File(_selectedImage!.path)), fit: BoxFit.cover)
                        : null
                  ),
                  child: _selectedImage == null 
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [Icon(Icons.add_a_photo, size: 40, color: Colors.grey), SizedBox(height: 8), Text("Tap to add cover image")],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              // 2. Common Fields
              _buildTextField(_titleController, "Title", icon: Icons.title),
              const SizedBox(height: 12),
              _buildTextField(_locationController, "Location", icon: Icons.location_on),
              const SizedBox(height: 12),
              _buildTextField(_descController, "Description", icon: Icons.description, maxLines: 4),
              const SizedBox(height: 12),

              // 3. Conditional Fields
              if (widget.type == 'Event') ...[
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
                          if (date != null) setState(() => _selectedDate = date);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: "Date", border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
                          child: Text(_selectedDate == null ? "Select Date" : DateFormat('MMM d, yyyy').format(_selectedDate!)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField(_timeController, "Time (e.g. 10 AM)", icon: Icons.access_time)),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _eventType,
                  decoration: const InputDecoration(labelText: "Type", border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
                  items: ["News", "Event", "Reunion", "Webinar", "Workshop"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _eventType = v!),
                )
              ] else ...[
                // Programme Fields
                Row(
                  children: [
                    Expanded(child: _buildTextField(_durationController, "Duration (e.g. 2 Weeks)", icon: Icons.timer)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField(_feeController, "Fee (e.g. ₦50,000)", icon: Icons.attach_money)),
                  ],
                )
              ],

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
                  child: _isSubmitting 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text("Post ${widget.type}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, {IconData? icon, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      validator: (v) => v == null || v.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}