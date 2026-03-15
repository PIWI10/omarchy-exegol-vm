# Guide : GitHub Repo + Publication AUR pour omarchy-exegol-vm

## Partie 1 — Créer le repo GitHub

### 1.1 Initialiser le repo

```bash
cd ~/omarchy-exegol-vm

# Init git
git init
git add .
git commit -m "Initial commit: omarchy-exegol-vm v0.1.0"
```

### 1.2 Créer le repo sur GitHub

Deux options :

**Option A — via `gh` CLI (recommandé sur Omarchy)**
```bash
# Si gh n'est pas installé
yay -S github-cli

# Se connecter
gh auth login

# Créer le repo et push
gh repo create omarchy-exegol-vm --public --source=. --remote=origin --push
```

**Option B — via le site GitHub**
1. Aller sur https://github.com/new
2. Nom : `omarchy-exegol-vm`
3. Public, pas de template
4. Ne PAS initialiser avec README (on en a déjà un)
5. Puis :
```bash
git remote add origin git@github.com:TON-USER/omarchy-exegol-vm.git
git branch -M main
git push -u origin main
```

### 1.3 Créer la première release (obligatoire pour l'AUR)

L'AUR télécharge une archive `.tar.gz` depuis une release taggée.

```bash
# Tagger la version
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

**Puis créer la release GitHub :**

```bash
# Via gh CLI
gh release create v0.1.0 --title "v0.1.0" --notes "Initial release: omarchy-exegol-vm

- Triple-layer encryption (host LUKS + ephemeral tmpfs + workspace LUKS)
- Cloud-init automated Ubuntu Server + Docker + Exegol setup
- SPICE display via qemux/qemu container
- Full Omarchy integration (Walker menu + Hyprland windowrules)
- Workspace encrypted container (LUKS2 Argon2id)"
```

### 1.4 Vérifier que l'archive est accessible

```bash
bash scripts/check-release-source.sh 0.1.0
```

Cela vérifie que le tag et l'archive `.tar.gz` sont bien en ligne.

---

## Partie 2 — Publier sur l'AUR

### 2.1 Prérequis

```bash
# Installer les outils de build Arch
sudo pacman -S --needed base-devel

# Avoir une clé SSH configurée pour aur.archlinux.org
# Si pas encore fait :
ssh-keygen -t ed25519 -C "ton-email@domain.com"
cat ~/.ssh/id_ed25519.pub
# → Copier cette clé dans ton profil AUR : https://aur.archlinux.org/account
```

### 2.2 Créer un compte AUR

1. Aller sur https://aur.archlinux.org/register
2. Créer le compte
3. Dans "Mon Compte" → coller ta clé SSH publique

### 2.3 Mettre à jour le PKGBUILD

Avant de soumettre, il faut calculer le vrai sha256sum de l'archive :

```bash
# Télécharger l'archive de release
curl -sL "https://github.com/TON-USER/omarchy-exegol-vm/archive/refs/tags/v0.1.0.tar.gz" -o /tmp/omarchy-exegol-vm-0.1.0.tar.gz

# Calculer le hash
sha256sum /tmp/omarchy-exegol-vm-0.1.0.tar.gz
```

Puis remplacer `SKIP` dans le PKGBUILD :
```bash
# Dans PKGBUILD, remplacer :
sha256sums=('SKIP')
# par :
sha256sums=('LE_VRAI_HASH_ICI')
```

**Mettre à jour aussi l'URL** dans PKGBUILD et .SRCINFO avec ton vrai username GitHub.

### 2.4 Tester le build localement

```bash
# Créer un répertoire de test propre
mkdir /tmp/aur-test && cd /tmp/aur-test

# Copier PKGBUILD
cp ~/omarchy-exegol-vm/PKGBUILD .

# Builder
makepkg -si
```

Si ça compile et s'installe sans erreur, c'est bon.

### 2.5 Régénérer le .SRCINFO

```bash
cd /tmp/aur-test   # là où est ton PKGBUILD
makepkg --printsrcinfo > .SRCINFO
```

Copier le `.SRCINFO` généré — c'est celui-là qui fait foi pour l'AUR.

### 2.6 Créer le paquet AUR

```bash
# Cloner le repo AUR (sera vide la première fois)
git clone ssh://aur@aur.archlinux.org/omarchy-exegol-vm.git ~/aur-omarchy-exegol-vm
cd ~/aur-omarchy-exegol-vm

# Copier les fichiers nécessaires
cp /tmp/aur-test/PKGBUILD .
cp /tmp/aur-test/.SRCINFO .

# Commiter et push
git add PKGBUILD .SRCINFO
git commit -m "Initial upload: omarchy-exegol-vm 0.1.0"
git push
```

C'est tout. Le paquet est maintenant sur l'AUR.

### 2.7 Vérifier

```bash
# Doit afficher les infos du paquet
yay -Si omarchy-exegol-vm

# Installer depuis l'AUR
yay -S omarchy-exegol-vm
```

---

## Partie 3 — Workflow pour les mises à jour

### 3.1 Nouvelle version

```bash
cd ~/omarchy-exegol-vm

# Faire tes modifications...
# Puis :
git add .
git commit -m "feat: description du changement"

# Bumper la version
git tag -a v0.1.1 -m "Release v0.1.1"
git push origin main --tags

# Créer la release GitHub
gh release create v0.1.1 --title "v0.1.1" --notes "Description des changements"

# Vérifier
bash scripts/check-release-source.sh 0.1.1
```

### 3.2 Mettre à jour l'AUR

```bash
cd ~/aur-omarchy-exegol-vm

# Éditer PKGBUILD
# → Changer pkgver=0.1.1
# → Mettre pkgrel=1
# → Mettre à jour sha256sums (télécharger la nouvelle archive et recalculer)

# Régénérer .SRCINFO
makepkg --printsrcinfo > .SRCINFO

# Push
git add PKGBUILD .SRCINFO
git commit -m "Update to 0.1.1"
git push
```

---

## Partie 4 — Structure des fichiers AUR vs GitHub

```
GitHub repo (omarchy-exegol-vm)        AUR repo (aur/omarchy-exegol-vm)
├── bin/                                ├── PKGBUILD          ← seuls ces
├── scripts/                            └── .SRCINFO            2 fichiers
├── share/
├── assets/
├── docs/
├── PKGBUILD          ← pour référence
├── .SRCINFO          ← pour référence
├── .gitignore
├── LICENSE
└── README.md

Le PKGBUILD dit à makepkg de télécharger l'archive
depuis GitHub releases, et d'installer les fichiers
aux bons endroits dans /usr/.
```

### Où les fichiers sont installés par pacman

```
/usr/bin/omarchy-exegol-vm
/usr/bin/omarchy-exegol-vm-integrate-os
/usr/bin/omarchy-exegol-vm-unintegrate-os
/usr/share/omarchy-exegol-vm/scripts/          ← install.sh, luks-setup.sh, etc.
/usr/share/omarchy-exegol-vm/omarchy-menu.sh
/usr/share/omarchy-exegol-vm/hypr/
/usr/share/icons/hicolor/256x256/apps/omarchy-exegol-vm.png
/usr/share/doc/omarchy-exegol-vm/
/usr/share/licenses/omarchy-exegol-vm/LICENSE
```

---

## Résumé rapide (cheat sheet)

```bash
# ── GITHUB ──
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin main --tags
gh release create v0.1.0 --title "v0.1.0" --notes "..."
bash scripts/check-release-source.sh 0.1.0

# ── AUR (première fois) ──
git clone ssh://aur@aur.archlinux.org/omarchy-exegol-vm.git
# copier PKGBUILD + .SRCINFO, commit, push

# ── AUR (mises à jour) ──
# éditer pkgver + sha256sums dans PKGBUILD
makepkg --printsrcinfo > .SRCINFO
git add PKGBUILD .SRCINFO && git commit -m "bump" && git push

# ── UTILISATEUR FINAL ──
yay -S omarchy-exegol-vm
omarchy-exegol-vm-integrate-os
omarchy-exegol-vm install
```
