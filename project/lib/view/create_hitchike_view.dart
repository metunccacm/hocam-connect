// lib/view/add_hitchike_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:provider/provider.dart';

import '../viewmodel/create_hitchikepost_viewmodel.dart';

class CreateHitchikeView extends StatefulWidget {
  const CreateHitchikeView({super.key});

  @override
  State<CreateHitchikeView> createState() => _CreateHitchikeViewState();
}

class _CreateHitchikeViewState extends State<CreateHitchikeView> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CreateHitchikeViewModel>();
    final locations = vm.locationOptions;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('List Destination'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: FormBuilder(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // FROM (top)
            DropdownButtonHideUnderline(
              child: FormBuilderDropdown<String>(
                name: 'from_location',
                decoration: const InputDecoration(
                  labelText: 'From *',
                  border: OutlineInputBorder(),
                ),
                items: locations
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Please choose the origin of the hitchike.' : null,
              ),
            ),
            const SizedBox(height: 16),

            // TO (bottom)
            DropdownButtonHideUnderline(
              child: FormBuilderDropdown<String>(
                name: 'to_location',
                decoration: const InputDecoration(
                  labelText: 'To *',
                  border: OutlineInputBorder(),
                ),
                items: locations
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Please choose the destination of the hitchike.' : null,
              ),
            ),
            const SizedBox(height: 16),

            // DATE (required)
            FormBuilderDateTimePicker(
              name: 'date',
              decoration: const InputDecoration(
                labelText: 'Date *',
                border: OutlineInputBorder(),
              ),
              inputType: InputType.date,
              firstDate: DateTime.now(),
              validator: (v) => v == null ? 'Please select a date.' : null,
            ),
            const SizedBox(height: 16),

            // TIME (required)
            FormBuilderDateTimePicker(
              name: 'time',
              decoration: const InputDecoration(
                labelText: 'Time *',
                border: OutlineInputBorder(),
              ),
              inputType: InputType.time,
              validator: (v) => v == null ? 'Please select a time.' : null,
            ),
            const SizedBox(height: 16),

            // SEATS (1..5)
            DropdownButtonHideUnderline(
              child: FormBuilderDropdown<int>(
                name: 'seats',
                decoration: const InputDecoration(
                  labelText: 'Empty Seats *',
                  border: OutlineInputBorder(),
                ),
                items: [1, 2, 3, 4, 5]
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                    .toList(),
                initialValue: 1,
                validator: (v) =>
                    (v == null || v < 1 || v > 5) ? 'Choose 1 to 5 seats.' : null,
              ),
            ),
            const SizedBox(height: 8),

            // Fuel support checkbox (stored as bool here; VM converts to 0/1)
            FormBuilderCheckbox(
              name: 'fuel_shared',
              title: const Text('Need fuel support?'),
            ),

            const SizedBox(height: 16),
            Text(
              '• Destination and origin entries are mandatory!\n'
              '• This system is NOT designed for and cannot be used as a money earning system!',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: vm.isListing
                    ? null
                    : () => context
                        .read<CreateHitchikeViewModel>()
                        .createPost(context, _formKey),
                child: vm.isListing
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('List Destination'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
