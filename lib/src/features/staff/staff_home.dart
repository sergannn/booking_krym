import 'package:flutter/material.dart';

import '../../data/models/user.dart';

class StaffHomePage extends StatelessWidget {
  const StaffHomePage({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Сотрудник — ${user.name}')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Раздел для сотрудников находится в разработке.'),
        ),
      ),
    );
  }
}
