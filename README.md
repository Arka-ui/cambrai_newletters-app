

# Cambrai Newsletters 📬

Projet complet permettant d'afficher des annonces locales sur une application iOS, avec un petit panneau de contrôle (panel) web simple à héberger.

---

## 📁 Structure du projet

```
/IOS APP/          ← Application iOS (SwiftUI)
/WEB PANEL/        ← Panel web (index.html + backend Python)
```

---

## 🔧 Prérequis

- Une machine (Windows, Linux, macOS ou VPS)
- Python 3.10+
- Accès internet (ou réseau local)
- Un iPhone ou simulateur pour tester l'app iOS

---

## 🌐 Mise en place du panel web

1. Aller dans le dossier `WEB PANEL` :

   ```bash
   cd WEB\ PANEL
   ```

2. Lancer le script backend principal :

   ```bash
   python3 main.py
   ```

   Le script sert l'API que l'application iOS interrogera.

3. Le fichier `index.html` peut être ouvert directement dans un navigateur pour afficher l'interface visuelle.

Note Importante : laisser libre l'accès a la base de données des annonces publiées mais sécurisé l'interface des création des annonces.

---

## 📱 App iOS (SwiftUI)

1. Ouvre le dossier `IOS APP` dans Xcode.

2. Remplace l’URL d’API par l’adresse publique (ou locale) de ta machine dans le fichier concerné (ex. `AnnoncesViewModel.swift`) :

   ```swift
   let apiURL = URL(string: "http://TON_IP:PORT/api/annonces_publiees")!
   ```

3. Lance l’app sur un simulateur ou un appareil.

---

## 🚀 Déploiement

1. Héberge le panel web sur une machine allumée 24/7 avec accès complet (par exemple un Raspberry Pi ou un VPS).

2. Modifie l’URL dans l’app iOS comme expliqué ci-dessus.

3. Compile et distribue ton app iOS.

---

## 🛠️ Technologies utilisées

- Swift / SwiftUI (app iOS)
- Python 3 (API)
- HTML (panel statique)
