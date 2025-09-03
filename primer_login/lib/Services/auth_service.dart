import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Configurar Google Sign-In con permisos para Google Drive
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'https://www.googleapis.com/auth/drive.file'],
  );

  /// === OBTENCIÓN DE CREDENCIALES DE INICIO DE SESIÓN CON GOOGLE ===
  Future<UserCredential> signInWithGoogle() async {
    // Forzamos elección de cuenta
    //await GoogleSignIn().signOut();
    //await _googleSignIn.signOut();

    // Trigger the authentication flow
    //final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception("Inicio de sesión cancelado por el usuario.");
    }

    // Obtenemos los datos de autenticación del usuario
    final GoogleSignInAuthentication googleAuth =  await googleUser/*?*/.authentication;

    // Creamos nuevas credenciales
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth/*?*/.accessToken,
      idToken: googleAuth/*?*/.idToken,
    );

    return await /*FirebaseAuth.instance*/_firebaseAuth.signInWithCredential(credential);
  }

  /// === CIERRE DE SESIÓN EN GOOGLE Y FIREBASE ===
  Future<void> signOut() async {
    // Cerramos sesión de Firebase y Google
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
  }

  Future<Map<String, String>> getAuthHeaders2() async {
    //final account = await _googleSignIn.signIn();
    GoogleSignInAccount? account = _googleSignIn.currentUser;
    // Intenta recuperar la sesión silenciosamente si no hay usuario actual
    if (account == null) {
      account = await _googleSignIn.signInSilently();
    }

    // Si sigue sin cuenta, fuerza nuevo inicio de sesión
    if (account == null) {
      account = await _googleSignIn.signIn();
    }

    // Si después de todo sigue sin cuenta válida
    if (account == null) {
      throw Exception("No se pudo autenticar al usuario con Google.");
    }

    final auth = await account/*?*/.authentication;
    if (auth.accessToken == null) throw Exception("No se pudo obtener el accessToken");

    return {
      'Authorization': 'Bearer ${auth/*?*/.accessToken}'
    };
  }

  User? get currentUser => _firebaseAuth.currentUser;

}