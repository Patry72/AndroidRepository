import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  // Ejecuta la app definida en MyApp
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ChangeNotifierProvider recoge info de alguna parte con ChangeNotifier
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Namer App',
        // Agregamos un tema para toda la app
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

// MyAppState contendrá los elementos necesarios
// ChangeNotifier indica que si hay algún cambio se notifica a otras partes
class MyAppState extends ChangeNotifier {
  var current = WordPair.random();

  void getNext() {
    current = WordPair.random();
    // Notificamos a las partes que escuchen este método
    notifyListeners();
  }

  // Lista vacía para agregar favoritos
  var favorites = <WordPair>[];

  // Función para añadir o eliminar de favoritos
  void toggleFavorite() {
    if (favorites.contains(current)) {
      favorites.remove(current);
    } else {
      favorites.add(current);
    }
    notifyListeners();
  }
}

// Widget con estado (puede almacenar variables suyas) para panel lateral
class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

// _ indica clase privada
class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = GeneratorPage();
        break;
      case 1:
        page = FavoritesPage();
        break;
      default:
        throw UnimplementedError('No widget for $selectedIndex');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  extended: constraints.maxWidth >= 600,
                  destinations: [
                    NavigationRailDestination(
                      icon: Icon(Icons.home),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.favorite),
                      label: Text('Favorites'),
                    ),
                  ],
                  selectedIndex: selectedIndex,  // Para mantener seleccionado un icono
                  onDestinationSelected: (value) {
                    print('selected: $value');
                    setState(() {
                      selectedIndex = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: page,
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}

// Widget sin estado para mostrar la lista de favoritos
class FavoritesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Obtenemos la lista de favoritos
    var appState = context.watch<MyAppState>();
    var favs = appState.favorites;

    if (favs.isEmpty) {
      return Center(
        child: Text('No favorites yet'),
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('You have ${favs.length} favorites'),
        ),
        for (var i in favs)
          ListTile(
            leading: Icon(Icons.favorite),
            title: Text(i.toString()),
          )
      ],
    );
  }
}

// Widget sin estado (usa las variables de MyAppState) para generar palabras
class GeneratorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Seguimiento del estado de la app
    var appState = context.watch<MyAppState>();
    var pair = appState.current;

    // Añadimos icono de corazón según comportamiento
    IconData icon;
    if (appState.favorites.contains(pair)) {
      icon = Icons.favorite;
    } else {
      icon = Icons.favorite_border;
    }

    // Creamos árbol de widgets
    // Scaffold es el widget de nvl superior
    return Scaffold(

      // Column es otro widget
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Creamos un widget para la palabra random
            BigCard(pair: pair),
            // Insertamos espacio
            SizedBox(height: 10),
            // Insertamos botón
            Row(
              // Indicamos que no ocupe todo el espacio horizontal disponible
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                    onPressed: () {
                      appState.toggleFavorite();
                    },
                    icon: Icon(icon),
                    label: Text('Like')
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    print('Button pressed!');
                    // Llamamos a la siguiente palabra
                    appState.getNext();
                  },
                  // Añadimos texto al botón
                  child: Text('Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

class BigCard extends StatelessWidget {
  const BigCard({
    super.key,
    required this.pair,
  });

  final WordPair pair;

  @override
  Widget build(BuildContext context) {
    // Obtenemos tema actual de la app
    final theme = Theme.of(context);
    // Copiamos el color del tema principal y cambiamos tamaño de letra
    final style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return Card(
      color: theme.colorScheme.primary,
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          pair.asPascalCase,
          style: style,
          // Cambiamos semántica al texto para, por ejemplo, que el lector de
          // pantalla lea cada palabra del parpor separado y no las una
          semanticsLabel: "${pair.first} ${pair.second}",
        ),
      ),
    );

  }
}