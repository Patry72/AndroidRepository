import 'package:flutter/material.dart';
//import 'package:flutter_widgets/Pages/HomePage.dart';
//import 'package:flutter_widgets/Services/auth_service.dart';

import '../Services/auth_service.dart';
import '../Services/drive_service.dart';
import 'HomePage.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: Center (
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                //Google Buttons
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
                  child: ElevatedButton(
                    onPressed: () async {

                      final credenciales = await AuthService().signInWithGoogle();

                      final driveService = DriveService();
                      final folderId = await driveService.createFolder("P2P-Audio-Share");

                      if (folderId != null) {
                        print("Carpeta creada con ID: $folderId");
                      } else {
                        print("Error al crear la carpeta");
                      }

                      debugPrint(credenciales.user?.displayName);
                      debugPrint(credenciales.user?.photoURL);
                      debugPrint(credenciales.user?.email);

                      Navigator.push( context, MaterialPageRoute(builder: (context) => const HomePage()));

                    },
                    child: Text("Continua con Google"),
                  ),
                ),


              ],
            ),
          )
      ),
    );
  }
}