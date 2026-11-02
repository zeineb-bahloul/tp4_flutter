# 🤖 Rapport d'utilisation d'un Agent IA — Workshop 4 : Flutter & Supabase Real-Time

**Étudiante :** Zeineb Bahloul  
**Date :** 02 Novembre 2026  
**Projet :** Waiting Room App — Synchronisation temps réel avec Supabase  
**Outil IA utilisé :** ChatGPT / Assistant IA  
**Modèle IA :** GPT-4o / Modèle IA conversationnel  

---

## 1. Présentation de l'outil

Pour ce TP, j'ai utilisé un assistant d'intelligence artificielle conversationnel. Je m'en suis servie comme d'un **tuteur et binôme de programmation (pair programmer)** pour me guider, m'expliquer les concepts que je ne comprenais pas bien (notamment le temps réel et les règles de sécurité dans Supabase), et me débloquer quand j'avais des erreurs dans mon code Flutter.

---

## 2. Contexte du TP

L'objectif du **Workshop 4** était de faire évoluer notre application de salle d'attente (Waiting Room App) réalisée lors des TP précédents :
- Remplacer le stockage en mémoire locale par une véritable base de données Cloud avec **Supabase**.
- Mettre en place la synchronisation **temps réel (Realtime)** pour que l'ajout ou le retrait d'un client se répercute instantanément sur tous les écrans connectés, sans recharger la page.
- Gérer la sécurité de la base avec le **Row Level Security (RLS)** et des politiques d'accès pour les utilisateurs anonymes.
- Garder une architecture propre avec **Provider** et créer un modèle de données typé `Client`.
- Écrire des tests unitaires et tester l'application en direct sur deux écrans en simultané.

---

## 3. Comment j'ai utilisé l'IA (Mes Prompts & les Réponses reçues)

Voici les principales questions que j'ai posées à l'IA tout au long de la réalisation du workshop, avec le résumé des explications et solutions qu'elle m'a apportées :

---

### 💬 Question 1 — Configuration de Supabase et sécurité RLS (Partie 1)

> **Moi :**  
> « Salut ! Je commence le TP 4 où on doit relier notre appli de salle d'attente Flutter à Supabase. J'ai créé ma table `clients` avec `id`, `name` et `created_at`. Mais dans le sujet ils parlent d'activer le RLS (Row Level Security), c'est quoi exactement et pourquoi c'est dangereux si je ne l'active pas ? Quelles requêtes SQL je dois mettre pour autoriser les utilisateurs à ajouter et retirer des clients sans compte ? »

> **ChatGPT :**  
> L'IA m'a expliqué que comme notre application mobile utilise une clé d'API publique (`anon key`), n'importe qui peut l'inspecter et faire des requêtes. Si le RLS n'est pas activé, une personne malveillante pourrait supprimer toutes les lignes de la table ou modifier les données des autres. Le RLS permet de définir des règles au niveau de la base elle-même.  
> Elle m'a donné les deux requêtes SQL adaptées à notre cas d'usage :
> 1. Autoriser l'insertion pour tout le monde (accès anonyme) :
>    ```sql
>    CREATE POLICY "Allow public insert"
>    ON clients FOR INSERT TO anon
>    WITH CHECK (true);
>    ```
> 2. Autoriser la suppression pour faire avancer la file :
>    ```sql
>    CREATE POLICY "Allow public delete"
>    ON clients FOR DELETE TO anon
>    USING (true);
>    ```

Grâce à cette réponse, j'ai activé le RLS dans la console Supabase et exécuté les deux requêtes dans le SQL Editor.

---

### 💬 Question 2 — Sécuriser les clés d'API avec un fichier .env (Partie 2)

> **Moi :**  
> « Je dois installer `supabase_flutter` et je veux mettre mon URL Supabase et ma clé anon dans un fichier `.env` pour ne pas les pousser sur GitHub par erreur. Comment je configure `flutter_dotenv` et comment j'initialise Supabase au démarrage dans `main.dart` ? »

> **ChatGPT :**  
> L'IA m'a détaillé la procédure :
> 1. Ajouter `supabase_flutter: ^2.7.0` et `flutter_dotenv: ^5.1.0` dans le fichier `pubspec.yaml`, et bien déclarer le `.env` sous `assets:`.
> 2. Ajouter impérativement `.env` dans mon `.gitignore` pour protéger mes identifiants.
> 3. Dans `main.dart`, rendre la fonction `main()` asynchrone, appeler `WidgetsFlutterBinding.ensureInitialized()`, charger le `.env` avec `await dotenv.load()`, puis initialiser Supabase avec `Supabase.initialize(url: ..., anonKey: ...)`.
> 4. Elle m'a aussi montré comment connecter l'utilisateur anonymement avec `Supabase.instance.client.auth.signInAnonymously()`.

J'ai appliqué ces étapes et mon application s'est bien connectée à mon projet Supabase au lancement.

---

### 💬 Question 3 — Création du modèle de données Client (Partie 3)

> **Moi :**  
> « Dans le TP d'avant, je manipulais juste des simples textes `String` pour les noms des clients. Là, le sujet demande de créer une vraie classe `Client` avec un UUID, un nom et un timestamp `created_at`. Comment je dois écrire ce modèle avec les méthodes `fromMap` et `toMap` pour que ça marche bien avec les données JSON renvoyées par Supabase ? »

> **ChatGPT :**  
> L'IA m'a expliqué que créer une classe dédiée permet d'avoir du typage fort (type safety) et d'éviter les erreurs de frappe comme `client['namme']` à l'exécution.  
> Elle m'a écrit le fichier `lib/models/client.dart` avec :
> - Un constructeur nommé `factory Client.fromMap(...)` qui extrait `id`, `name`, et convertit la date reçue en texte vers un vrai objet Dart `DateTime.parse(map['created_at'])`.
> - Une méthode `toMap()` pour réexporter l'objet en Map au format ISO-8601.

J'ai créé ce fichier dans mon projet et testé la sérialisation.

---

### 💬 Question 4 — Synchronisation en temps réel dans QueueProvider (Partie 3)

> **Moi :**  
> « C'est la partie où je bloque le plus : je dois refactorer mon `QueueProvider`. Je veux que ma liste récupère les clients de Supabase au démarrage, mais surtout qu'elle se mette à jour toute seule en temps réel quand quelqu'un ajoute ou supprime un client depuis un autre téléphone, sans devoir faire un refresh manuel. Comment faire ça avec les flux Realtime de Supabase ? »

> **ChatGPT :**  
> L'IA m'a décomposé la logique à mettre dans `QueueProvider` :
> - Au démarrage (constructeur), appeler une méthode `_fetchInitialClients()` qui fait un `select()` trié par `created_at` pour remplir la liste initiale.
> - Créer une souscription Realtime sur la table `clients` : écouter les événements `insert` pour ajouter le nouveau client dans la liste et retrier, et les événements `delete` pour filtrer le client supprimé avec `removeWhere()`.
> - Appeler `notifyListeners()` à chaque événement pour que les widgets Flutter se redessinent automatiquement.
> - Implémenter les méthodes asynchrones `addClient(name)`, `removeClient(id)` et `nextClient()` qui appellent directement l'API Supabase (`insert`, `delete`).
> - Ne pas oublier d'annuler l'abonnement dans `dispose()` pour éviter les fuites mémoire.

J'ai implémenté ce code dans `lib/queue_provider.dart` et la file d'attente est devenue complètement réactive.

---

### 💬 Question 5 — Améliorer l'interface utilisateur dans main.dart (Partie 4)

> **Moi :**  
> « Dans mon interface, quand je clique sur le bouton "Add", le texte que j'ai tapé reste dans le champ, ce qui n'est pas pratique. Et je veux aussi afficher la date d'arrivée du client dans la liste avec un bouton pour le supprimer, plus le bouton vert "Next Client" en bas. Comment organiser mon `main.dart` avec Provider ? »

> **ChatGPT :**  
> L'IA m'a conseillé de créer un `StatefulWidget` pour gérer un `TextEditingController`, ce qui permet d'appeler `_controller.clear()` dès qu'on valide l'ajout.  
> Pour la liste, elle m'a montré comment utiliser un `Consumer<QueueProvider>` qui reconstruit un `ListView.builder` avec :
> - Des `Card` contenant le nom en titre et la date tronquée en sous-titre (`client.createdAt.toString().split(' ')[0]`).
> - Un bouton poubelle rouge (`IconButton`) qui appelle `context.read<QueueProvider>().removeClient(client.id)`.
> - Un message centré "No one in queue yet..." si la file est vide.
> - Le bouton vert "Next Client" en bas qui appelle `nextClient()`.

J'ai adapté mon `main.dart` avec cette structure et l'interface est devenue beaucoup plus agréable et ergonomique.

---

### 💬 Question 6 — Tests unitaires et validation de la synchronisation (Partie 5)

> **Moi :**  
> « Comment je peux écrire un test unitaire avec `flutter test` pour vérifier que mon modèle et mon QueueProvider fonctionnent bien ? Et pour le test d'intégration obligatoire du sujet, comment je peux tester la synchronisation en direct sur mon ordinateur si je n'ai qu'un seul téléphone ? »

> **ChatGPT :**  
> L'IA m'a donné deux conseils :
> 1. Pour les tests unitaires : elle m'a aidée à écrire `test/queue_provider_test.dart` pour tester la conversion du modèle `Client` (`fromMap` / `toMap`), ainsi que les méthodes `addClient()`, `removeClient()` et `nextClient()`.
> 2. Pour la démonstration multi-écrans : elle m'a expliqué qu'il suffisait de lancer l'application en mode Web (`flutter run -d chrome`) ou de l'ouvrir dans **deux onglets de navigateur côte à côte**. Quand j'ajoute un nom dans l'onglet A, il s'affiche immédiatement sur l'onglet B sans recharger, et en cliquant sur "Next Client" sur l'onglet B, il disparaît instantanément des deux côtés.

J'ai exécuté les tests avec succès (`All tests passed!`) et vérifié la synchronisation entre deux fenêtres.

---

## 4. Tableau récapitulatif des fichiers du projet

| Fichier | Modification | Rôle |
|---------|--------------|------|
| `.env` | **Nouveau** | Contient mes clés secrètes Supabase (`URL` et `ANON_KEY`) hors de Git |
| `pubspec.yaml` | Modifié | Ajout de `supabase_flutter` et `flutter_dotenv` |
| `lib/models/client.dart` | **Nouveau** | Modèle de données typé (`id`, `name`, `createdAt`) avec `fromMap` et `toMap` |
| `lib/queue_provider.dart` | Modifié | Gestionnaire d'état connecté à Supabase en Realtime avec Provider |
| `lib/main.dart` | Modifié | Interface utilisateur (champ de saisie, liste temps réel, bouton Next Client) |
| `test/queue_provider_test.dart` | **Nouveau** | Tests unitaires pour valider le modèle et les actions de la file d'attente |

---

## 5. Ce que j'ai appris grâce à ce TP et à l'IA

- ✅ **Comprendre le fonctionnement d'un BaaS (Backend-as-a-Service) :** J'ai vu comment Supabase permet d'avoir une base de données PostgreSQL prête à l'emploi et des API prêtes à consommer en Flutter sans devoir créer un serveur Node.js ou Spring Boot.
- ✅ **L'importance de la sécurité RLS :** J'ai compris que sur une base accessible directement depuis un client mobile/web, la sécurité ne se fait pas par un mot de passe backend mais par des règles de sécurité directement sur les tables.
- ✅ **La puissance du Realtime :** Découvrir comment les WebSockets permettent de pousser les mises à jour instantanément vers l'application sans devoir faire de requêtes répétées ("polling").
- ✅ **La rigueur du typage Dart :** L'intérêt d'avoir un vrai modèle `Client` plutôt que de manipuler des `Map<String, dynamic>` brutes dans l'UI.
- ✅ **L'esprit critique face à l'IA :** L'IA m'a donné d'excellentes bases, mais j'ai dû adapter certaines parties (comme la gestion des erreurs réseau ou le cycle de vie du controller de texte) pour que tout fonctionne parfaitement dans mon projet.

---

## 6. Conclusion

L'utilisation de l'IA m'a permis d'avancer plus rapidement dans le TP en comprenant chaque étape au lieu de simplement copier du code. Elle m'a servi d'aide précieuse pour éclaircir les notions complexes comme le RLS et le Realtime de Supabase, tout en me laissant le soin d'intégrer le code et de tester son bon fonctionnement sur mon application.
