# openclaw_docker_windows

Des outils pour gérer OpenClaw simplement et de manière sûre.

Ces fichiers sont à télécharger et à copier dans votre répertoire d'installation OpenClaw :

git clone https://github.com/openclaw/openclaw.git
cd openclaw

Le répertoire de configuration est dans "config" (et non ~/.openclaw) mais vous pouvez le changer dans le script.

Ensuite lancez :
OpenClaw_Launcher.bat

Il va créér les containers docker comme ceci : 
<img width="1197" height="795" alt="image" src="https://github.com/user-attachments/assets/2b354e34-c5ed-4026-b38e-bcaa062f1a99" />

Ensuite vous pourrez accéder à l'interface avec http://localhost:18789/

Si vous avez un problème de pairing, vous pouvez lancer OpenClaw_Pairing.bat il vous aidera (mais les options 3 et 4 ne fonctionnent pas pour le moment, et vous pouvez le faire par le navigateur de toutes façons).

