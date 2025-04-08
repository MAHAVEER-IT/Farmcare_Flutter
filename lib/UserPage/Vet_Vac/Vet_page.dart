import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class PetVaccinationApp extends StatelessWidget {
  const PetVaccinationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pet Care Companion',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          primary: Colors.teal.shade700,
          secondary: Colors.amber.shade600,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  late List<Pet> pets = [];
  late AnimationController _fabAnimationController;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _initializeNotifications();
    _loadPets();
    _fabAnimationController.forward();
  }

  static const platform = MethodChannel('com.example.sms/send');

  Future<bool> sendSMS(String phone, String message) async {
    try {
      await platform.invokeMethod('sendSMS', {
        'phone': phone,
        'message': message,
      });
      print("SMS sent");
      return true;
    } on PlatformException catch (e) {
      print("Error: ${e.message}");
      return false;
    }
  }

  Future<void> _initializeNotifications() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _loadPets() async {
    final prefs = await SharedPreferences.getInstance();
    final petsJson = prefs.getStringList('pets') ?? [];
    setState(() {
      pets = petsJson.map((json) => Pet.fromJson(jsonDecode(json))).toList();
    });
    _checkUpcomingVaccinations();
  }

  Future<void> _savePets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'pets', pets.map((pet) => jsonEncode(pet.toJson())).toList());
  }

  void _checkUpcomingVaccinations() {
    final now = DateTime.now();
    bool updated = false;

    for (var pet in pets) {
      List<Vaccination> toAdd = [];
      for (var vaccine in pet.vaccinations) {
        // Schedule notification
        if (vaccine.dueDate.isAfter(now)) {
          _scheduleNotification(pet, vaccine);
        }

        // Handle recurring vaccines
        if (vaccine.isRecurring && vaccine.dueDate.isBefore(now)) {
          DateTime nextDate = vaccine.dueDate;
          while (nextDate.isBefore(now)) {
            nextDate = nextDate.add(const Duration(days: 28));
          }
          toAdd.add(Vaccination(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: vaccine.name,
            dueDate: nextDate,
            notes: vaccine.notes,
            isRecurring: true,
          ));
          updated = true;
        }
      }
      pet.vaccinations.addAll(toAdd);
    }

    if (updated) _savePets();
  }

  Future<void> _scheduleNotification(Pet pet, Vaccination vaccine) async {
    final androidDetails = const AndroidNotificationDetails(
      'vaccine_channel',
      'Vaccine Reminders',
      importance: Importance.high,
      priority: Priority.max,
    );

    const iosDetails = DarwinNotificationDetails();

    await flutterLocalNotificationsPlugin.zonedSchedule(
      vaccine.id.hashCode,
      '${pet.name} Vaccine Reminder',
      '${vaccine.name} is due on ${DateFormat.MMMd().format(vaccine.dueDate)}',
      tz.TZDateTime.from(
          vaccine.dueDate.subtract(const Duration(days: 3)), tz.local),
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  void _addNewPet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPetScreen(
          onPetAdded: (newPet) {
            setState(() {
              pets.add(newPet);
              _savePets();
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pet Care Companion'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => _showNotificationsSettings(context),
          ),
        ],
      ),
      body: pets.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: pets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _PetCard(
                pet: pets[index],
                onTap: () => _navigateToDetail(pets[index]),
                onDelete: () => _deletePet(index),
              ),
            ),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(
          parent: _fabAnimationController,
          curve: Curves.fastOutSlowIn,
        ),
        child: FloatingActionButton.extended(
          onPressed: _addNewPet,
          icon: const Icon(Icons.pets),
          label: const Text('Add Pet'),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('images/pet.png', width: 200),
          const SizedBox(height: 20),
          Text(
            'No Pets Added Yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          const Text('Start by adding your furry friend!'),
        ],
      ),
    );
  }

  void _navigateToDetail(Pet pet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PetDetailScreen(
          pet: pet,
          onUpdate: (updatedPet) {
            setState(() {
              final index = pets.indexWhere((p) => p.id == updatedPet.id);
              pets[index] = updatedPet;
              _savePets();
            });
          },
          onDelete: () => Navigator.pop(context),
          sendSMS: sendSMS,
        ),
      ),
    );
  }

  void _deletePet(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Pet'),
        content: Text('Are you sure you want to remove ${pets[index].name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                pets.removeAt(index);
                _savePets();
              });
              Navigator.pop(context);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showNotificationsSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Settings'),
        content: const Text('Configure your notification preferences...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  final Pet pet;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PetCard(
      {required this.pet, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final age = _calculateAge(pet.birthDate);
    final nextVaccine = pet.vaccinations
        .where((v) => v.dueDate.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade100, Colors.teal.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _PetAvatar(type: pet.type),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pet.name, style: Theme.of(context).textTheme.titleLarge),
                  Text('${pet.type} • ${pet.breed}'),
                  Text('Age: $age'),
                  if (nextVaccine.isNotEmpty)
                    Text(
                      'Next: ${nextVaccine.first.name} - ${DateFormat.MMMd().format(nextVaccine.first.dueDate)}',
                      style: TextStyle(color: Colors.teal.shade700),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red.shade300),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  String _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int years = now.year - birthDate.year;
    int months = now.month - birthDate.month;
    if (months < 0) {
      years--;
      months += 12;
    }
    return years > 0 ? '$years years' : '$months months';
  }
}

class _PetAvatar extends StatelessWidget {
  final String type;
  final double size;

  const _PetAvatar({required this.type, this.size = 56});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (type.toLowerCase()) {
      case 'dog':
        icon = Icons.pets;
        break;
      case 'cat':
        icon = Icons.catching_pokemon;
        break;
      case 'bird':
        icon = Icons.air;
        break;
      default:
        icon = Icons.help_outline;
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.teal.shade100,
      child: Icon(icon, size: size * 0.6, color: Colors.teal.shade700),
    );
  }
}

class AddPetScreen extends StatefulWidget {
  final Function(Pet) onPetAdded;

  const AddPetScreen({super.key, required this.onPetAdded});

  @override
  State<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _vetNameController = TextEditingController();
  final _vetPhoneController = TextEditingController();
  DateTime _birthDate = DateTime.now().subtract(const Duration(days: 365));
  String _petType = 'Dog';
  final List<String> _petTypes = ['Dog', 'Cat', 'Bird', 'Other'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Pet')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(_nameController, 'Pet Name', Icons.pets),
              const SizedBox(height: 20),
              _buildTypeDropdown(),
              const SizedBox(height: 20),
              _buildBirthDatePicker(),
              const SizedBox(height: 20),
              _buildTextField(_breedController, 'Breed', Icons.flag),
              const SizedBox(height: 20),
              _buildTextField(_vetNameController, 'Vet Name', Icons.person),
              const SizedBox(height: 20),
              _buildTextField(
                _vetPhoneController,
                'Vet Phone',
                Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Pet Profile'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                ),
                onPressed: _submitForm,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      keyboardType: keyboardType,
      validator: (value) => value!.isEmpty ? 'Required field' : null,
    );
  }

  Widget _buildTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _petType,
      decoration: InputDecoration(
        labelText: 'Pet Type',
        prefixIcon: const Icon(Icons.category),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: _petTypes
          .map((type) => DropdownMenuItem(
                value: type,
                child: Text(type),
              ))
          .toList(),
      onChanged: (value) => setState(() => _petType = value!),
    );
  }

  Widget _buildBirthDatePicker() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _birthDate,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (date != null) setState(() => _birthDate = date);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Birth Date',
          prefixIcon: const Icon(Icons.cake),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat.yMMMd().format(_birthDate)),
            const Icon(Icons.calendar_today),
          ],
        ),
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final newPet = Pet(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        type: _petType,
        breed: _breedController.text,
        birthDate: _birthDate,
        vetName: _vetNameController.text,
        vetPhone: _vetPhoneController.text,
        vaccinations: [],
      );
      widget.onPetAdded(newPet);
      Navigator.pop(context);
    }
  }
}

class PetDetailScreen extends StatefulWidget {
  final Pet pet;
  final Function(Pet) onUpdate;
  final VoidCallback onDelete;
  final Future<bool> Function(String, String) sendSMS;

  const PetDetailScreen({
    super.key,
    required this.pet,
    required this.onUpdate,
    required this.onDelete,
    required this.sendSMS,
  });

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends State<PetDetailScreen> {
  late Pet pet;

  @override
  void initState() {
    super.initState();
    pet = widget.pet;
  }

  @override
  Widget build(BuildContext context) {
    final upcomingVaccines = pet.vaccinations
        .where((v) => v.dueDate.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final pastVaccines = pet.vaccinations
        .where((v) => v.dueDate.isBefore(DateTime.now()))
        .toList()
      ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

    return Scaffold(
      appBar: AppBar(
        title: Text(pet.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editPetProfile,
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _PetProfileHeader(pet: pet),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSectionTitle('Upcoming Vaccinations'),
                ..._buildVaccineList(upcomingVaccines),
                _buildSectionTitle('Vaccination History'),
                ..._buildVaccineList(pastVaccines, isPast: true),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addVaccination,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }

  List<Widget> _buildVaccineList(List<Vaccination> vaccines,
      {bool isPast = false}) {
    if (vaccines.isEmpty) {
      return [
        const ListTile(
          title: Text('No vaccinations found'),
          leading: Icon(Icons.info),
        )
      ];
    }

    return vaccines
        .map((vaccine) => _VaccineCard(
              vaccine: vaccine,
              isPast: isPast,
              onDelete: () => _deleteVaccination(vaccine),
            ))
        .toList();
  }

  void _addVaccination() {
    showDialog(
      context: context,
      builder: (context) => VaccineDialog(
        onSave: (newVaccine) async {
          setState(() {
            pet.vaccinations.add(newVaccine);
            widget.onUpdate(pet);
          });

          if (pet.vetPhone.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Veterinarian phone number is missing. SMS not sent.'),
              ),
            );
            return;
          }

          final message = 'New vaccination scheduled for ${pet.name}: '
              '${newVaccine.name} due on ${DateFormat.yMMMd().format(newVaccine.dueDate)}. '
              'Notes: ${newVaccine.notes.isNotEmpty ? newVaccine.notes : "None"}';

          final success = await widget.sendSMS(pet.vetPhone, message);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? 'SMS reminder sent to veterinarian!'
                    : 'Failed to send SMS reminder',
              ),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
        },
      ),
    );
  }

  void _deleteVaccination(Vaccination vaccine) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vaccination'),
        content: const Text('Are you sure you want to delete this record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                pet.vaccinations.remove(vaccine);
                widget.onUpdate(pet);
                Navigator.pop(context);
              });
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _editPetProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Pet Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: pet.name),
                decoration: const InputDecoration(
                  labelText: 'Pet Name',
                  icon: Icon(Icons.pets),
                ),
                onChanged: (value) => pet = Pet(
                  id: pet.id,
                  name: value,
                  type: pet.type,
                  breed: pet.breed,
                  birthDate: pet.birthDate,
                  vetName: pet.vetName,
                  vetPhone: pet.vetPhone,
                  vaccinations: pet.vaccinations,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: pet.breed),
                decoration: const InputDecoration(
                  labelText: 'Breed',
                  icon: Icon(Icons.flag),
                ),
                onChanged: (value) => pet = Pet(
                  id: pet.id,
                  name: pet.name,
                  type: pet.type,
                  breed: value,
                  birthDate: pet.birthDate,
                  vetName: pet.vetName,
                  vetPhone: pet.vetPhone,
                  vaccinations: pet.vaccinations,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: pet.vetName),
                decoration: const InputDecoration(
                  labelText: 'Vet Name',
                  icon: Icon(Icons.person),
                ),
                onChanged: (value) => pet = Pet(
                  id: pet.id,
                  name: pet.name,
                  type: pet.type,
                  breed: pet.breed,
                  birthDate: pet.birthDate,
                  vetName: value,
                  vetPhone: pet.vetPhone,
                  vaccinations: pet.vaccinations,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: pet.vetPhone),
                decoration: const InputDecoration(
                  labelText: 'Vet Phone',
                  icon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                onChanged: (value) => pet = Pet(
                  id: pet.id,
                  name: pet.name,
                  type: pet.type,
                  breed: pet.breed,
                  birthDate: pet.birthDate,
                  vetName: pet.vetName,
                  vetPhone: value,
                  vaccinations: pet.vaccinations,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onUpdate(pet);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _PetProfileHeader extends StatelessWidget {
  final Pet pet;

  const _PetProfileHeader({required this.pet});

  @override
  Widget build(BuildContext context) {
    final age = _calculateAge(pet.birthDate);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          _PetAvatar(type: pet.type),
          const SizedBox(height: 16),
          Text(pet.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('${pet.type} • $age old'),
          const SizedBox(height: 16),
          _buildInfoRow('Veterinarian', pet.vetName),
          _buildInfoRow('Contact', pet.vetPhone),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  String _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    final difference = now.difference(birthDate);
    final years = difference.inDays ~/ 365;
    final months = (difference.inDays % 365) ~/ 30;
    return years > 0 ? '$years years' : '$months months';
  }
}

class VaccineDialog extends StatefulWidget {
  final Function(Vaccination) onSave;

  const VaccineDialog({super.key, required this.onSave});

  @override
  State<VaccineDialog> createState() => _VaccineDialogState();
}

class _VaccineDialogState extends State<VaccineDialog> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _isRecurring = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Vaccination'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Vaccine Name',
                icon: Icon(Icons.medical_services),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Due Date'),
              subtitle: Text(DateFormat.yMMMd().format(_dueDate)),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _dueDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                );
                if (date != null) setState(() => _dueDate = date);
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Recurring every 28 days'),
              value: _isRecurring,
              onChanged: (value) => setState(() => _isRecurring = value),
            ),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                icon: Icon(Icons.notes),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final newVaccine = Vaccination(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: _nameController.text,
              dueDate: _dueDate,
              notes: _notesController.text,
              isRecurring: _isRecurring,
            );
            widget.onSave(newVaccine);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _VaccineCard extends StatelessWidget {
  final Vaccination vaccine;
  final bool isPast;
  final VoidCallback onDelete;

  const _VaccineCard({
    required this.vaccine,
    required this.isPast,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          isPast ? Icons.check_circle : Icons.circle_notifications,
          color: isPast ? Colors.green : Colors.amber,
        ),
        title: Text(vaccine.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat.yMMMd().format(vaccine.dueDate)),
            if (vaccine.notes.isNotEmpty)
              Text(vaccine.notes,
                  style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

// Pet and Vaccination classes remain same as previous implementation with added fields
class Pet {
  final String id;
  final String name;
  final String type;
  final String breed;
  final DateTime birthDate;
  final String vetName;
  final String vetPhone;
  final List<Vaccination> vaccinations;

  Pet({
    required this.id,
    required this.name,
    required this.type,
    required this.breed,
    required this.birthDate,
    required this.vetName,
    required this.vetPhone,
    required this.vaccinations,
  });

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      breed: json['breed'],
      birthDate: DateTime.parse(json['birthDate']),
      vetName: json['vetName'],
      vetPhone: json['vetPhone'],
      vaccinations: (json['vaccinations'] as List)
          .map((v) => Vaccination.fromJson(v))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'breed': breed,
      'birthDate': birthDate.toIso8601String(),
      'vetName': vetName,
      'vetPhone': vetPhone,
      'vaccinations': vaccinations.map((v) => v.toJson()).toList(),
    };
  }
}

class Vaccination {
  final String id;
  final String name;
  final DateTime dueDate;
  final String notes;
  final bool isRecurring;
  bool reminderSent;

  Vaccination({
    required this.id,
    required this.name,
    required this.dueDate,
    this.notes = '',
    this.isRecurring = false,
    this.reminderSent = false,
  });

  factory Vaccination.fromJson(Map<String, dynamic> json) {
    return Vaccination(
      id: json['id'],
      name: json['name'],
      dueDate: DateTime.parse(json['dueDate']),
      notes: json['notes'] ?? '',
      isRecurring: json['isRecurring'] ?? false,
      reminderSent: json['reminderSent'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dueDate': dueDate.toIso8601String(),
      'notes': notes,
      'isRecurring': isRecurring,
      'reminderSent': reminderSent,
    };
  }
}
