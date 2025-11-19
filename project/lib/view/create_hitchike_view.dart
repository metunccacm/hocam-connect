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

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'List Destination',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.appBarTheme.foregroundColor ?? cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor ?? cs.surface,
        foregroundColor: theme.appBarTheme.foregroundColor ?? cs.onSurface,
        elevation: 1,
      ),
      body: FormBuilder(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // FROM
            DropdownButtonHideUnderline(
              child: FormBuilderDropdown<String>(
                name: 'from_location',
                decoration: InputDecoration(
                  labelText: 'From *',
                  border: const OutlineInputBorder(),
                ),
                dropdownColor: cs.surface,
                items: locations
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Please choose the origin of the hitchike.'
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            // TO
            DropdownButtonHideUnderline(
              child: FormBuilderDropdown<String>(
                name: 'to_location',
                decoration: const InputDecoration(
                  labelText: 'To *',
                  border: OutlineInputBorder(),
                ),
                dropdownColor: cs.surface,
                items: locations
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Please choose the destination of the hitchike.'
                    : null,
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
                dropdownColor: cs.surface,
                items: [1, 2, 3, 4, 5]
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                    .toList(),
                initialValue: 1,
                validator: (v) => (v == null || v < 1 || v > 5)
                    ? 'Choose 1 to 5 seats.'
                    : null,
              ),
            ),
            const SizedBox(height: 8),

            // Fuel support checkbox (stored as bool here; VM converts to 0/1)
            FormBuilderCheckbox(
              name: 'fuel_shared',
              title: Text(
                'Need fuel support?',
                style:
                    theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface),
              ),
              checkColor: cs.onPrimary,
              activeColor: cs.primary,
            ),

            const SizedBox(height: 16),
            // Warnings
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '• Destination and origin entries are mandatory!\n'
                '• This system is NOT designed for and cannot be used as a money earning system!',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onErrorContainer),
              ),
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
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  disabledBackgroundColor: cs.surfaceVariant,
                  disabledForegroundColor: cs.onSurfaceVariant,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
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
