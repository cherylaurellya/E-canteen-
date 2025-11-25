import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart'; // Pastikan file ini ada hasil dari flutterfire configure

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kantin Poliwangi',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const MenuPage(),
    );
  }
}

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});
  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  // Referensi Koleksi Firestore
  final CollectionReference _menuRef =
      FirebaseFirestore.instance.collection('menus');
  final CollectionReference _orderRef =
      FirebaseFirestore.instance.collection('orders');

  // Variabel State untuk Filter (TUGAS TANTANGAN)
  String _selectedCategory = 'All'; // Default menampilkan semua

  // Helper: Format Rupiah
  String formatRupiah(int price) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(price);
  }

  // Fungsi: Menampilkan Dialog Pemesanan
  void _showOrderDialog(String menuName, int price) {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Pesan $menuName"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: "Nama Pemesan",
            hintText: "Contoh: Budi (TI-2A)",
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Batal")),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                // KIRIM DATA KE FIREBASE (Write)
                _orderRef.add({
                  'menu_item': menuName,
                  'price': price,
                  'customer_name': nameController.text,
                  'status': 'Menunggu',
                  'timestamp': FieldValue.serverTimestamp(),
                });

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Pesanan berhasil dikirim!")),
                );
              }
            },
            child: const Text("Pesan Sekarang"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("E-Canteen Poliwangi")),
      body: Column(
        children: [
          // --- BAGIAN TUGAS TANTANGAN: TOMBOL FILTER ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFilterButton('All'),
                const SizedBox(width: 10),
                _buildFilterButton('Makanan'),
                const SizedBox(width: 10),
                _buildFilterButton('Minuman'),
              ],
            ),
          ),

          // --- DAFTAR MENU (StreamBuilder) ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // LOGIKA FILTER: Jika All ambil semua, jika tidak filter by category
              stream: _selectedCategory == 'All'
                  ? _menuRef.snapshots()
                  : _menuRef.where('category', isEqualTo: _selectedCategory).snapshots(),
              builder: (context, snapshot) {
                // 1. Handling Error
                if (snapshot.hasError) {
                  return const Center(child: Text("Terjadi kesalahan koneksi."));
                }
                // 2. Handling Loading
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // 3. Handling Data Kosong
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Menu belum tersedia."));
                }

                // 4. Menampilkan Data
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    Map<String, dynamic> data =
                        doc.data() as Map<String, dynamic>;

                    // --- SAFETY CHECK (PENGAMAN DATA NULL) ---
                    // Mengambil data dengan nilai default jika kosong
                    String name = data['name'] ?? 'Tanpa Nama';
                    int price = data['price'] ?? 0;
                    bool isAvailable = data['isAvailable'] ?? false;
                    String category = data['category'] ?? '-';
                    
                    // Ambil huruf depan dengan aman
                    String initialChar = '?';
                    if (name.isNotEmpty) {
                      initialChar = name[0];
                    }

                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          child: Text(initialChar), // Menampilkan huruf depan
                        ),
                        title: Text(name,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(formatRupiah(price)),
                            // Menampilkan kategori kecil di bawah harga
                            Text(
                              category,
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: isAvailable
                              ? () => _showOrderDialog(name, price)
                              : null, // Matikan tombol jika habis
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isAvailable 
                              ? Colors.orange 
                              : Colors.grey,
                          ),
                          child: Text(
                            isAvailable ? "Pesan" : "Habis",
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Widget bantuan untuk membuat tombol filter
  Widget _buildFilterButton(String category) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: _selectedCategory == category ? Colors.orange : Colors.grey[300],
        foregroundColor: _selectedCategory == category ? Colors.white : Colors.black,
      ),
      child: Text(category),
    );
  }
}