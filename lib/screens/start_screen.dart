import 'package:flutter/material.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF007274),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 🔹 Imagen superior con curva inferior
            ClipPath(
              clipper: CurvedClipper(),
              child: Container(
                width: double.infinity,
                height: size.height * 0.45,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/cartagena_inicio.png'), // tu imagen
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 🔹 Logo circular
            Container(
              height: 100,
              width: 100,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Image.asset('assets/icono.png', fit: BoxFit.contain),
              ),
            ),

            const SizedBox(height: 20),

            // 🔹 Nombre y subtítulo
            const Text(
              "Safe Tourism Cartagena",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Welcome! Discover safely",
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
            ),

            const SizedBox(height: 40),

            // 🔹 Botón de Login
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7D00),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Have an account? Login",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 🔹 Botón de Registro
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/register');
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white, width: 2),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Create an account",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}

// 🔹 Curva inferior de la imagen superior
class CurvedClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width / 2, size.height,
      size.width, size.height - 40,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}