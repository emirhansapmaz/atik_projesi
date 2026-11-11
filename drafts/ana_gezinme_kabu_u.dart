import 'package:flutter/material.dart';

class MainShellView extends StatefulWidget {
  const MainShellView({super.key});

  @override
  State<MainShellView> createState() => _MainShellViewState();
}

class _MainShellViewState extends State<MainShellView> {
  int _currentIndex = 0;

  // Sayfalar geliştikçe gerçek ekran sınıflarıyla değiştirilecektir
  final List<Widget> _pages = [
    const Center(child: Text('1. Ana Sayfa (Dashboard)', style: TextStyle(fontSize: 18))),
    const Center(child: Text('2. Atık Tara (Kamera / TFLite)', style: TextStyle(fontSize: 18))),
    const Center(child: Text('3. Atık Haritası (OpenStreetMap)', style: TextStyle(fontSize: 18))),
    const Center(child: Text('4. Profil & İstatistikler', style: TextStyle(fontSize: 18))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Colors.green),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt, color: Colors.green),
            label: 'Tara',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map, color: Colors.green),
            label: 'Harita',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Colors.green),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}