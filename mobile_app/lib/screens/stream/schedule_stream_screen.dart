import 'package:flutter/material.dart';

class ScheduleStreamScreen extends StatefulWidget {
  const ScheduleStreamScreen({Key? key}) : super(key: key);

  @override
  State<ScheduleStreamScreen> createState() => _ScheduleStreamScreenState();
}

class _ScheduleStreamScreenState extends State<ScheduleStreamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _scheduledTime;
  String _visibility = 'public';
  String _latency = 'normal';
  final List<String> _tags = [];
  final _tagController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Stream'),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Stream Title *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Scheduled time
                      ListTile(
                        title: const Text('Scheduled Start Time'),
                        subtitle: Text(_scheduledTime?.toString() ?? 'Go live immediately'),
                        trailing: const Icon(Icons.schedule),
                        onTap: _selectDateTime,
                      ),
                      const Divider(),

                      // Visibility
                      const Text('Visibility'),
                      RadioListTile<String>(
                        title: const Text('Public'),
                        value: 'public',
                        groupValue: _visibility,
                        onChanged: (value) => setState(() => _visibility = value!),
                      ),
                      RadioListTile<String>(
                        title: const Text('Unlisted'),
                        value: 'unlisted',
                        groupValue: _visibility,
                        onChanged: (value) => setState(() => _visibility = value!),
                      ),
                      RadioListTile<String>(
                        title: const Text('Private'),
                        value: 'private',
                        groupValue: _visibility,
                        onChanged: (value) => setState(() => _visibility = value!),
                      ),
                      const Divider(),

                      // Latency
                      const Text('Latency'),
                      DropdownButtonFormField<String>(
                        value: _latency,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'normal', child: Text('Normal')),
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                          DropdownMenuItem(value: 'ultraLow', child: Text('Ultra Low')),
                        ],
                        onChanged: (value) => setState(() => _latency = value!),
                      ),
                      const SizedBox(height: 16),

                      // Tags
                      const Text('Tags'),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _tagController,
                              decoration: const InputDecoration(
                                hintText: 'Add a tag',
                                border: OutlineInputBorder(),
                              ),
                              onFieldSubmitted: _addTag,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _addTag(_tagController.text),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _tags.map((tag) => Chip(
                          label: Text(tag),
                          deleteIcon: const Icon(Icons.close),
                          onDeleted: () => _removeTag(tag),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              // Create button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _createStream,
                  child: const Text('Create Stream'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _scheduledTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _addTag(String tag) {
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  void _createStream() {
    if (_formKey.currentState!.validate()) {
      // TODO: Implement stream creation API call
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stream scheduled successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }
}