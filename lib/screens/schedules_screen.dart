import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/schedule_service.dart';
import '../services/bluetooth_service.dart';
import '../services/command_service.dart';

class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({super.key});

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  final ScheduleService _scheduleService = ScheduleService();
  final BluetoothService _bluetooth = BluetoothService();
  final CommandService _command = CommandService();
  List<Schedule> _schedules = [];
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
    _bluetooth.connectionStream.listen((connected) {
      if (mounted) {
        setState(() => _isConnected = connected);
      }
    });
    _isConnected = _bluetooth.isConnected;
  }

  void _loadSchedules() {
    setState(() {
      _schedules = _scheduleService.getSchedules();
    });
  }

  Future<void> _addSchedule() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScheduleEditScreen()),
    );
    // Reload if result is true OR if we just came back (safer)
    if (result == true) {
      _loadSchedules();
    }
  }

  Future<void> _editSchedule(Schedule schedule) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleEditScreen(schedule: schedule),
      ),
    );
    if (result == true) {
      _loadSchedules();
    }
  }

  Future<void> _deleteSchedule(Schedule schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: Text('Delete "${schedule.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Optimistic update
      setState(() {
        _schedules.removeWhere((s) => s.id == schedule.id);
      });
      await _scheduleService.deleteSchedule(schedule.id);
      _loadSchedules();
    }
  }

  Future<void> _toggleSchedule(Schedule schedule) async {
    final updated = Schedule(
      id: schedule.id,
      name: schedule.name,
      command: schedule.command,
      time: schedule.time,
      weekdays: schedule.weekdays,
      enabled: !schedule.enabled,
      notifyBeforeMinutes: schedule.notifyBeforeMinutes,
    );
    await _scheduleService.updateSchedule(updated);
    _loadSchedules();
  }

  Future<void> _runNow(Schedule schedule) async {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect to Bluetooth device first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    await _command.sendCommand(schedule.command, source: 'Schedule (Manual)');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Command sent: ${schedule.command}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addSchedule,
          ),
        ],
      ),
      body: _schedules.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.schedule, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No schedules yet'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _addSchedule,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Schedule'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _schedules.length,
              itemBuilder: (context, index) {
                final schedule = _schedules[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: Icon(
                      schedule.enabled
                          ? Icons.schedule
                          : Icons.schedule_outlined,
                      color: schedule.enabled ? Colors.green : Colors.grey,
                    ),
                    title: Text(schedule.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Command: ${schedule.command}'),
                        Text(
                            'Time: ${DateFormat('HH:mm').format(schedule.time)}'),
                        if (schedule.isRecurring())
                          Text('Repeat: ${_formatWeekdays(schedule.weekdays)}')
                        else
                          Text(
                              'Date: ${DateFormat('yyyy-MM-dd').format(schedule.time)}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(schedule.enabled
                              ? Icons.toggle_on
                              : Icons.toggle_off),
                          color: schedule.enabled ? Colors.green : Colors.grey,
                          onPressed: () => _toggleSchedule(schedule),
                        ),
                        PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'run',
                              child: Text('Run Now'),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'run') {
                              _runNow(schedule);
                            } else if (value == 'edit') {
                              _editSchedule(schedule);
                            } else if (value == 'delete') {
                              _deleteSchedule(schedule);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatWeekdays(List<int> weekdays) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (weekdays.contains(0)) return 'Once';
    return weekdays.map((d) => days[d - 1]).join(', ');
  }
}

class ScheduleEditScreen extends StatefulWidget {
  final Schedule? schedule;

  const ScheduleEditScreen({super.key, this.schedule});

  @override
  State<ScheduleEditScreen> createState() => _ScheduleEditScreenState();
}

class _ScheduleEditScreenState extends State<ScheduleEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _commandController;
  late TimeOfDay _selectedTime;
  late DateTime _selectedDate;
  List<int> _selectedWeekdays = [];
  bool _isRecurring = false;
  int? _notifyBeforeMinutes;
  bool _isSaving = false;

  final List<String> _commonCommands = [
    'light on',
    'light off',
    'fan on',
    'fan off',
    'all on',
    'all off',
    'neon off',
    'red',
    'green',
    'blue',
    'white',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.schedule != null) {
      final s = widget.schedule!;
      _nameController = TextEditingController(text: s.name);
      _commandController = TextEditingController(text: s.command);
      _selectedTime = TimeOfDay.fromDateTime(s.time);
      _selectedDate = s.time;
      _isRecurring = s.isRecurring();
      _selectedWeekdays = List.from(s.weekdays);
      _notifyBeforeMinutes = s.notifyBeforeMinutes;
    } else {
      _nameController = TextEditingController();
      _commandController = TextEditingController();
      _selectedTime = TimeOfDay.now();
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  void _toggleWeekday(int weekday) {
    setState(() {
      if (_selectedWeekdays.contains(weekday)) {
        _selectedWeekdays.remove(weekday);
      } else {
        _selectedWeekdays.add(weekday);
        _selectedWeekdays.sort();
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final time = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final weekdays = _isRecurring ? _selectedWeekdays : [0];

      final schedule = Schedule(
        // Ensure ID fits in 32-bit int for Android notifications (Max 2,147,483,647)
        // Using modulo 100,000,000 allows us to multiply by 10 for recurring IDs without overflow
        id: widget.schedule?.id ??
            (DateTime.now().millisecondsSinceEpoch % 100000000),
        name: _nameController.text,
        command: _commandController.text.toLowerCase().trim(),
        time: time,
        weekdays: weekdays,
        enabled: widget.schedule?.enabled ?? true,
        notifyBeforeMinutes: _notifyBeforeMinutes,
      );

      final scheduleService = ScheduleService();
      if (widget.schedule != null) {
        await scheduleService.updateSchedule(schedule);
      } else {
        await scheduleService.addSchedule(schedule);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.schedule == null ? 'New Schedule' : 'Edit Schedule'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Schedule Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _commandController,
              decoration: InputDecoration(
                labelText: 'Command',
                border: const OutlineInputBorder(),
                suffixIcon: PopupMenuButton<String>(
                  icon: const Icon(Icons.arrow_drop_down),
                  itemBuilder: (context) => _commonCommands
                      .map((cmd) => PopupMenuItem(value: cmd, child: Text(cmd)))
                      .toList(),
                  onSelected: (value) {
                    _commandController.text = value;
                  },
                ),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Time'),
                    subtitle: Text(_selectedTime.format(context)),
                    trailing: const Icon(Icons.access_time),
                    onTap: _selectTime,
                  ),
                ),
                if (!_isRecurring)
                  Expanded(
                    child: ListTile(
                      title: const Text('Date'),
                      subtitle:
                          Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: _selectDate,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Recurring'),
              value: _isRecurring,
              onChanged: (value) {
                setState(() => _isRecurring = value);
                if (!value) {
                  _selectedWeekdays = [];
                }
              },
            ),
            if (_isRecurring) ...[
              const SizedBox(height: 8),
              const Text('Repeat on:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: [
                  for (int i = 1; i <= 7; i++)
                    FilterChip(
                      label: Text([
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun'
                      ][i - 1]),
                      selected: _selectedWeekdays.contains(i),
                      onSelected: (_) => _toggleWeekday(i),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save Schedule'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
