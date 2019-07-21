# Geneweb et js_of_ocaml: retours d'expérience

Compiler geneweb en javascript afin de l'embarquer dans une
application cordova et/ou electron.

## js_of_ocaml et jingoo

Après quelques hésitation, j'ai choisi de réutiliser le système de
templates sur lequel je continue de travailler. Avec les modifications
faites (et toujours plus avec celles à venir), jingoo est un language
de template très complet, et toutes les données présentent dans
geneweb (personnes, familles, et leur attributs).

Cependant, jingoo ne fonctionne pas immédiatement en javascript car il
utilise des mutex et un binding à la lib pcre pour les quelques
utilisation de regex. Problème reglé en virant les mutex, qui était
inutiles dans notre cas, et en switchant sur un autre lib, 100% OCaml,
et donc qui va être compilé sans souci par js_of_ocaml. Donc,
l'écriture des pages est "ouverte à tous", et l'interface pour
communiquer entre jingoo et geneweb est déjà là.

_Note: la suppression du mutex ainsi que le passage à la lib
100% OCaml ont finalement été incorporés dans jingoo_

## js_of_ocaml et geneweb

### Electron

Commençons par le plus simple : l'application electron.

Tout semble bien fonctionner, j'ai fait une appli avec 3 pages qui
semble faire le café, le binding node.js de js_of_ocaml prend en
charge les opérations dont on a besoin, notamment les accès disque.

### Cordova

Évidemment, c'est moins simple du côté de cordova pour ce qui est des
entrées/sorties système.

Premièrement, dans tous les cas, l'ouverture d'un fichier nécessite de
charger tout son contenu en mémoire. Il est possible d’implémenter un
système de stockage avec cette problématique en tête, privilégiant
l'utilisation de la mémoire et non la rapidité. Il est aussi possible
d'imaginer un proxy qui découpe les fichiers trop gros en plusieurs
plus petit. Mais il s'agit là d'un problème qui n'en est peut être pas
un. Cela dépend surtout des performance de la plateforme. Passons donc
au second problème.

En javascript, une API FileSystem existe. Malheureusement, celle-ci
est asynchrone, donc impossible à binder au runtime ocaml. En faisant
un open, puis un read, il y a toutes les chances que le fichier ne
soit en fait pas encore ouvert, et donc de se manger une erreur.

Voyons les solution envisagées pour contourner ce problème.

#### La version synchrone de l'api FileSystem

C'est ce l'approche que j'ai choisi d'explorer le plus, et
malheureusement je n'ai pas réussi à obtenir quelque chose de
totalement fonctionnel. Pour plus de détails sur les problèmes
techniques non solutionnés, se referer à cetta [pull
request](https://github.com/ocsigen/js_of_ocaml/pull/704).

Les fichiers texte classique fonctionnent, les données marshalées à la
main (le fichier base) non. Le problème peut venir de geneweb, qui
réimplémente les fonctions d'input/output au lieu d'utiliser le
marshaling de base de OCaml. Il est possible (probable ?) qu'avec un
moteur de stockage différent utilisant les fonctions natives d'OCaml,
cette approche fonctionne.

Un autre problème de cette approche est que la version synchrone n'est
disponible que dans les webworkers (et avec webkit, mais vu que
cordova est basé sur une webview webkit, pas un problème ici), ce qui
implique une pile plus petite que dans le thread principal. Ça
implique également de devoir utiliser plusieurs threads, et donc de
consommer plus de ressources.

Aussi, les webworkers se voient allouer une pile plus petit que le
thread principal. Javascript n'optimisant pas la récursion terminale,
certaines parties du code sont donc plus propices à un
débordement de pile... À voir si on peut avoir une option de
compilation permettant de dire à cordova d'augmenter la taille de la
pile.

#### Lecture en xhr synchrone et écriture asynchrone

js_of_ocaml embarque un pseudo-filesystem. On peut enregistrer des
chaines de caratères et l'associer à un chemin d'accès, émulant ainsi
la possiblité d'écrire et de lire des fichiers avec les même appel
qu'on ferait dans n'importe quel programme OCaml.

Côté javascript, cela correspond à l'implementation d'une classe
`MlFakeDevice` qui definit les fonctions qui serviront à émuler les
fonctions de lecture/écriture sur disque de la bibliothèque standard
OCaml.

On peut étendre cette classe : dans le cas ou le fichier requis ne donne pas de résultat, au lieu de lever une exception, on tente de récupérer le contenu via une requête xhr synchrone.

```javascript
// File runtime/fs_fake.js

MlFakeDevice.prototype.xhr = function (name) {
    var xhr = new XMLHttpRequest () ;
    xhr.open ('GET', name, false) ;
    xhr.overrideMimeType ('text/plain; charset=x-user-defined') ;
    xhr.send (null) ;
    if (xhr.status != 200) { caml_raise_no_such_file (name) }
    var res = xhr.responseText ;
    var len = res.length ;
    var str = caml_create_bytes (len) ;
    for (var i = 0 ; i < len ; i++) {
        caml_bytes_unsafe_set (str, i, res.charCodeAt (i) & 0xff)
    }
    return str ;
}
```

```diff
-    caml_raise_no_such_file (this.nm(name));
+    this.content[name] = new MlFakeFile (this.xhr (this.nm (name)));
+    return this.content[name];
```

Il ne reste plus qu'à utiliser cette nouvelle fonctionnalité, en
spécialisant les chemins d'accès quand nous sommes dans une
application cordova.

```javascript
// File runtime/fs_cordova.js

MlCordovaDevice.prototype.xhr = function (name) {
    var path = joo_global_object.cordova.file.applicationDirectory + name ;
    MlFakeDevice.prototype.xhr.call(this, name) ;
}
```

L'écriture se fait dans le buffer du faux filesystem. Pour ce qui est
de la _vraie_ écriture, celle sur le disque, on peut envisager
d'écrire le fichier sur le disque lors de la fermeture du
fichier. L'API javascript ne permettant pas un contrôle fin de
l'écriture du fichier (il faut tout écrire d'une block, pas de `fseek`
disponible,...). Évidemment, si on écrit un programme qui écrit dans
un fichier sans le fermer avant de quitter, alors cela pose problème,
mais qui ferait ça ?

Le problème que je n'ai pas réussi à résoudre : impossible d'atteindre
des fichiers autres que ceux qui sont dans le dossier www de l'appli
avec ma requête xhr, un dossier en lecture seule et qu'on ne peut donc
pas utiliser pour stocker la base.

#### Avec un serveur embarqué en plus

J'ai essayé, sans succès, d'utiliser un plugin cordova permettant
d'utiliser un serveur embarqué qui se chargerait uniquement de servir
les fichiers du filesystem que je n'arrivait pas à atteindre avec mq requête xhr. Je suis vite passé à autre chose, mais ça m'a l'air possible d'utiliser cette solution. À creuser ?

#### Précharger tous les fichiers au lancement de l'app

Comme vu précédement, js_of_ocaml permet d'enregistrer le contenu de
fichiers dans un faux filsystem afin de les utiliser comme des
fichiers normaux dans le reste du programme. Le problème ici c'est
qu'il faut avoir charger en mémoire TOUS les fichiers dont on va avoir
besoin dans l'appli. On pourrait donc charger tous les fichiers
nécessaires au préchauffage de l'application, et la démarrer une fois
le faux filesytem en place, mais ça posera sûrement des problème pour
les grosses base. Cela dit, la méthode fonctionne, je l'ai testé pour
lire les fichiers depuis un champs `<input type="file" multiple>`. Je
n'ai pas essayé de le faire avec un script qui charge les fichier
depuis le stockage du téléphone mais le principe est le même.

#### Précharger les fichiers lorsque l'on va en avoir besoin

Il est aussi possible charger les fichier dont on va avoir besoin pour
traiter une requête, et traiter la requête dans le callback. Bien
qu'assez contraignant (il faut avoir en têtes les fichiers dont on va
avoir besoin pour telle ou telle action), ce n'est pas infaisable. À
choisir entre ça et la solution précédente, je ne saurais me décider.

<a class="home-btn" href="/">Retout à l’accueil</a>
