# Détection des lieux - Implémentation

_Détails techniques d'un module capable de regrouper les lieux par
région : comment rester efficace en temps CPU et en
consommation mémoire._

_Note: pour plus de concision, je parlais indifféremment de __région__
pour désigner les pays, les régions et les sous-régions_

## Rappel sur la représentation mémoire

Dans [un article
précédent](/blog/posts/2019-07-22-detection-des-lieux/), nous avons vu
que chaque région était représentée par un entier. Inutile d'aller
plus loin dans l'optimisation de l'utilisation de la mémoire.

## La comparaison des chaînes de caractères

Là ou le bât blesse, c'est au niveau du stockage des chaines de
caractères associées à chaque région. En effet, il faut être capable
de trouver une correspondance avec un pays dans de nombreuses
langues. Au moins les langues officiellement supportées par GeneWeb,
mais également l'orthographe du pays dans sa langue officielle, ainsi
que toutes les variantes (e.g. `United States`, `USA`, ...) connues.

### Réduction du nombre de chaînes à comparer

Inutile d'entrer toutes les variantes (avec ou sans accent/trait
d'union, représentation originale et représentation ascii), car les
chaînes sont normalisées avant comparaison. Les chaînes ne seront
comparées qu'après avoir été converties en représentation ASCII, sans
espace et en minuscule. Ainsi, _"Alpes-de-Haute-Provence"_ et _"Alpes
de Haute Provence"_ auront la même valeur une fois normalisés.

### Optimisation de la comparaison

Normaliser évite de devoir entrer un certain nombre de chaînes, mais
c'est surtout un avantage pour le développeur, qui n'aura besoin de
renseigner moins de valeurs. Moins de valeurs, cela représente tout de
même beaucoup de valeurs si on veut couvrir l'ensemble des régions du
monde.

Afin de ne pas grossir la taille de GeneWeb inutilement, nous n'allons
pas garder ces chaînes dans le programme, nous allons en fait garder
uniquement la valeur du hash de ces chaînes, soit un entier. Cela
devient tout de suite beaucoup plus acceptable. Nous appellerons cet
entier _la clé_.

Ainsi, lorsqu'on voudra comparer une chaîne, nous allons d'abord
calculer sa clé, puis chercher si elle correspond à une valeur dans
notre liste de régions.

## L'implémentation

Nous avons vu précédemment comment ne pas embarquer toutes les chaînes
de caractères dans le programme. Cependant, écrire à la main les
clés, de nos régions serait fastidieux et une source d'erreurs faciles à
faire.

Nous allons donc générer le module de comparaison à partir de nos
données source (les régions et leurs écritures possibles).

Pour cela, rien de plus simple, un programme OCaml va se charger
d'écrire ce module pour nous. À partir de notre liste de variants et
des chaînes de caractères associées, notre générateur va calculer les
clés de chaque valeur et générer le pattern matching correspondant.

Par exemple, à partir de cette liste de données:

```ocaml
[ Foo, ["Foo";"Föo";"Le Foo";"The Foo"]
; Bar, ["Bar";"Bãr";"Le Bar";"Baar"] ]
```

et en admettant que les clés correspondantes sont:

```ocaml
[ Foo, [1;1;2;3]
; Bar, [4;4;5;6] ]
```

Notre programme génèrera ce code:

```ocaml
let fn = function
| 1 | 2 | 3 -> Foo
| 4 | 5 | 6 -> Bar
| _ -> raise Not_found
```

La fonction `fn` obtenue n'aura donc pas besoin de connaitre les
valeurs initiales des chaînes de caractères, et sera très
efficace.

## Benchmark des différentes pistes

Recherche dichotomique
```
Latencies for 10000 iterations of "Place.country":
Place.country:  6.57 WALL ( 5.45 usr +  1.12 sys =  6.57 CPU) @ 1522.42/s (n=10000)
Latencies for 10000 iterations of "Place.region":
Place.region:  1.16 WALL ( 1.16 usr +  0.00 sys =  1.16 CPU) @ 8632.36/s (n=10000)
Latencies for 10000 iterations of "Place.subregion":
Place.subregion:  1.07 WALL ( 1.07 usr +  0.00 sys =  1.07 CPU) @ 9332.44/s (n=10000)
	Command being timed: "_build/default/benchmark/bench.exe"
	User time (seconds): 25.96
	System time (seconds): 1.12
	Percent of CPU this job got: 99%
	Elapsed (wall clock) time (h:mm:ss or m:ss): 0:27.08
	Average shared text size (kbytes): 0
	Average unshared data size (kbytes): 0
	Average stack size (kbytes): 0
	Average total size (kbytes): 0
	Maximum resident set size (kbytes): 39340
	Average resident set size (kbytes): 0
	Major (requiring I/O) page faults: 0
	Minor (reclaiming a frame) page faults: 1182093
	Voluntary context switches: 1
	Involuntary context switches: 382
	Swaps: 0
	File system inputs: 0
	File system outputs: 0
	Socket messages sent: 0
	Socket messages received: 0
	Signals delivered: 0
	Page size (bytes): 4096
	Exit status: 0
```

Hashtbl:
```
Latencies for 10000 iterations of "Place.country":
Place.country:  0.76 WALL ( 0.76 usr +  0.00 sys =  0.76 CPU) @ 13243.17/s (n=10000)
Latencies for 10000 iterations of "Place.region":
Place.region:  0.86 WALL ( 0.86 usr +  0.00 sys =  0.86 CPU) @ 11677.84/s (n=10000)
Latencies for 10000 iterations of "Place.subregion":
Place.subregion:  0.51 WALL ( 0.51 usr +  0.00 sys =  0.51 CPU) @ 19613.53/s (n=10000)
	Command being timed: "_build/default/benchmark/bench.exe"
	User time (seconds): 20.72
	System time (seconds): 0.00
	Percent of CPU this job got: 99%
	Elapsed (wall clock) time (h:mm:ss or m:ss): 0:20.73
	Average shared text size (kbytes): 0
	Average unshared data size (kbytes): 0
	Average stack size (kbytes): 0
	Average total size (kbytes): 0
	Maximum resident set size (kbytes): 22696
	Average resident set size (kbytes): 0
	Major (requiring I/O) page faults: 0
	Minor (reclaiming a frame) page faults: 3007
	Voluntary context switches: 1
	Involuntary context switches: 286
	Swaps: 0
	File system inputs: 0
	File system outputs: 0
	Socket messages sent: 0
	Socket messages received: 0
	Signals delivered: 0
	Page size (bytes): 4096
	Exit status: 0
```

Pattern matching:
```
Latencies for 10000 iterations of "Place.country":
Place.country:  0.74 WALL ( 0.74 usr +  0.00 sys =  0.74 CPU) @ 13501.58/s (n=10000)
Latencies for 10000 iterations of "Place.region":
Place.region:  0.81 WALL ( 0.81 usr +  0.00 sys =  0.81 CPU) @ 12286.04/s (n=10000)
Latencies for 10000 iterations of "Place.subregion":
Place.subregion:  0.48 WALL ( 0.48 usr +  0.00 sys =  0.48 CPU) @ 20882.41/s (n=10000)
	Command being timed: "_build/default/benchmark/bench.exe"
	User time (seconds): 20.80
	System time (seconds): 0.00
	Percent of CPU this job got: 99%
	Elapsed (wall clock) time (h:mm:ss or m:ss): 0:20.81
	Average shared text size (kbytes): 0
	Average unshared data size (kbytes): 0
	Average stack size (kbytes): 0
	Average total size (kbytes): 0
	Maximum resident set size (kbytes): 22476
	Average resident set size (kbytes): 0
	Major (requiring I/O) page faults: 0
	Minor (reclaiming a frame) page faults: 3002
	Voluntary context switches: 1
	Involuntary context switches: 340
	Swaps: 0
	File system inputs: 0
	File system outputs: 0
	Socket messages sent: 0
	Socket messages received: 0
	Signals delivered: 0
	Page size (bytes): 4096
	Exit status: 0
```

## Les collisions de hash

Pour le moment, je n'ai pas eu de problème de collision de hash (c'est
à dire deux chaines de caractères qui seraient représentées par la
même clé). Il est peu probable que cela arrive, car il faudrait que
deux pays différents produisent le même hash. Pour les régions et
sous-régions, le hash n'a besoin d'être unique qu'à l'intérieur de
leur pays, pas à un niveau mondial.

Si cela venait à se produire, la chose ne serait cependant pas
dramatique, il faudrait simplement stocker un deuxième hash (la chaîne
moins un caractère, par exemple) capable de départager les deux
régions impliquées dans la collision.

## Conclusion

Nous avons un code très efficace pour regrouper les lieux par région.

Que reste-t-il à faire ?

Le plus évident, mais pas le moins fastidieux: remplir la liste des
régions, et la maintenir à jour. Ces données peuvent être ajoutées au
fur et à mesure, et le monde devrait être suffisamment stable pour ne
pas changer les noms des régions tous les quatre matins.

Ensuite, comment gérer les anciennes régions ? Certains pays
disparaissent, les frontières bougent, les régions sont réformées.

Pour le moment, rien n'est prévu pour gérer les anciens noms de
régions. Comme statué dans l'article précédent, c'est la localisation
sur une carte actuelle qui nous intéressera ici. Mais la question
mérite tout de même que l'on y réfléchisse.
