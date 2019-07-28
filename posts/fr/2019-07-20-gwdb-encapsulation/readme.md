# GWDB : l'encapsulation

_Retour sur les récents changements apportés du module Gwdb :
l'encapsulation._

À l'origine, il n'existait qu'un seul backend de stockage des
données d'une base. Nous l'appellerons gwdb1.

Pour des raisons de performance, une deuxième façon de stocker les
données a vu le jour (gwdb2).

Ce nouveau moteur de stockage ne pouvait pas remplace l'ancien, les
deux devaient cohabiter. La solution choisie à été d'encapsuler les
données.

## Faire cohabiter deux implémentations : l'encapsulation

Disons qu'une bibliothèque incorpore un module qui permet d'afficher
des nombres entiers.  L'implémentation initiale se base sur le type
`int` de OCaml.

```ocaml
type t = int

let input ch : t = input_value ch

let to_string : t -> string = string_of_int
```

Maintenant, on décide d'ajouter une implémentation des nombres qui les
stock comme des flottants, tout en devant garder la compatibilité avec
les données stockées comme des entiers.

```ocaml
type t = I of int | F of float

let input ch : t =
  if Sys.getenv "VERSION" = "1"
  then I (input_value ch : int)
  else F (input_value ch : float)

let to_string : t -> string = function
  | I i -> string_of_int i
  | F f -> string_of_float f
```

### Les performances

Le coup de cette encapsulation est tout à fait négligeable. Mais cela
ne veut pas dire qu'il est nul non plus. Ni d'un point de vue temps
CPU, ni d'un point de vue occupation mémoire.

### L'évolutivité

Si l'on décide d'expérimenter sur le module Gwdb, l'écriture de
nouvelles fonctionnalités ne s'en trouve pas facilitée, puisque l'on
doit prévoir les cas de pattern matching pour chaque variant, même si
ce n'est que pour lever une exception.

```ocaml
let to_int = function I i -> i | _ -> assert false
```

On peut toujours désactiver les warnings de pattern matching
incomplet, mais le faire à un niveau global est une très mauvaise
idée, et le faire localement ne rend pas l'écriture de code vraiment
plus simple.

### La taille de l'exécutable

Même si l'utilisateur final ne va utiliser qu'une seule des
implémentations du moteur de stockage, l'encapsulation fait que
l'exécutable final devra embarquer le code pour gérer **tous** les
moteurs de stockages disponibles dans le code source.

### Les dépendances

Plus important que le problème de taille de l'exécutable que l'on
vient de voir, une nouvelle implémentation peut amener de nouvelles
dépendances.

Un backend utilisant sqlite reposera sur une bibliothèque externe
permettant la communication avec les bases sqlite. Un utilisateur
n'ayant aucune utilité à cela se verra tout de même dépendant de cette
nouvelle bibliothèque.

Encore plus grave, il se peut que certaines bibliothèques ne soient
pas disponibles sur toutes les plateformes, rendant ainsi le programme
entier incompatible avec ces plateformes. Ce serait un motif tout à
fait légitime pour refuser l'ajout d'un nouveau système de stockage.

## Faire cohabiter deux implémentations : les bibliothèques virtuelles

Il est possible avec OCaml, et c'est une pratique relativement
courante, d'utiliser ce qu'on appelle _The link hack_.

Grossièrement, en passant la bonne option au compilateur, on peut
compiler toute l'algorithmie de GeneWeb en ne proposant aucune
implémentation concrète pour le module Gwdb. Il ne sera nécessaire de
fournir une implémentation qu'au moment de compiler l'exécutable.

On peut donc passer l'implémentation de Gwdb que l'on désire au moment
de la compilation, embarquant uniquement le code nécessaire au backend
désiré, laissant tomber le code correspondant à tous les autres
backends et à leurs dépendances !

Cerise sur le gâteau, [dune](https://dune.build/) intègre depuis
peu toute la gestion des options de compilations pour nous (cf
http://rgrinberg.com/posts/virtual-libraries/).

### Ce qu'on y perd

À vrai dire, pas grand-chose : La possibilité d'avoir un exéctuable
universel pouvant être utilisé avec tous les formats de bases.
