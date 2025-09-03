import 'package:flutter/material.dart';
import '../Services/auth_service.dart';
import '../Services/drive_service.dart';
import 'HomePage.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              //Color(0xFFE0F2F1), // Azul claro
              Color(0xFFE1BEE7),
              //Color(0xFF1DE9B6),
              Color(0xFF26A69A),
              Color(0xFF004D40), // Morado
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
            child: Center (
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo de la App (en lugar del título)
                  Image.asset(
                    'assets/images/P2P-logo-in-app.png', // <- Cambia esta ruta si tu logo está en otra ubicación
                    width: 260,
                    height: 260,
                  ),

                  // Título de la App
                  /*const Text(
                    'P2P Audio Share',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          offset: Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),*/

                  const SizedBox(height: 150),

                  //Google Button
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
                    child: ElevatedButton(
                      onPressed: () async {

                        final credentials = await AuthService().signInWithGoogle();

                        final driveService = DriveService();
                        final folderId = await driveService.createFolder("P2P-Audio-Share");

                        /*if (folderId != null) {
                        print("Carpeta creada con ID: $folderId");
                      } else {
                        print("Error al crear la carpeta");
                      }*/

                        final String? userName = credentials.user?.displayName;

                        debugPrint(userName);
                        debugPrint(credentials.user?.photoURL);
                        debugPrint(credentials.user?.email);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => HomePage(
                                folderId: folderId ?? "", username: userName ?? "Invitado",)),
                        );

                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/google-icon.png',
                            height: 24.0,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Iniciar sesión",
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),


                ],
              ),
            )
        ),
      )

    );
  }
}