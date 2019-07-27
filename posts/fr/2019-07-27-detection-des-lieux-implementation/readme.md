# Détection des lieux - Implémentation

_Détails techniques d'un module capable de regrouper les lieux par
régions : comment rester efficace en temps CPU et en
consommation mémoire._

_Note: pour plus de consision, je parlais indifférement de __région__
pour désigner les pays, les régions et les sous-régions_

## Rappel sur la représentation mémoire

Dans [un post précédent](/posts/2019-07-22-detection-des-lieux/), nous
avons vu que chaque région était représenté par un entier. Inutile
d'aller plus loin dans l'optimisation de l'utilisation de la mémoire.

## La comparaison des chaînes de caractères

Là ou le bât blesse, c'est au niveau du stockage des chaines de
caractères associées à chaque région. En effet, il faut être capable
de trouver une correspondance avec un pays dans de nombreuses
langues. Au moins les langues officiellement supportées par GeneWeb,
mais également le'orthographe du pays dans sa langue officielle, ainsi
que toutes les variantes (e.g. `United States`, `USA`, ...) connues.

### Réduction du nombre de chaînes à comparer

Inutile d'entrer toutes les variantes (avec ou sans accent/trait
d'union, représentation originale et représentation ascii), car les
chaines sont normalisés avant comparaison. Les chaînes ne seront
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
devient tout de suite beaucoup plus acceptable. Nous appelerons cet
entier _la clé_.

Ainsi, lorsqu'on voudra comparer une chaîne, nous allons d'abord
calculer sa clé, puis chercher si elle correspond à une valeur dans
notre liste de régions.

## L'implémentation

Nous avons vu précédemment comment ne pas embarquer toutes les chaînes
de caractères dans le programme. Cependant, écrirer à la main les
clés, de nos régions serait fastidieux et une source d'erreur facile à
faire.

Nous allons donc générer le module de comparaison à partir de nos
données source (les régions et leur écritures possibles).

Pour cela, rien de plus simple, un programme OCaml va se charger
d'écrire ce module pour nous. À partir de notre liste de variants et
des chaînes de caractères associées, notre générateur va calculer les
clés de chaques valeurs et générer le patter matching correspondant.

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
efficace, en temps CPU et en consommation mémoire.

## Les collisions de hash

Pour le moment, je n'ai pas eu de problème de collision de hash (c'est
à dire deux chaines de charactère qui seraient représentées par la
même clé). Il est peu probable que cela arrive, car il faudrait que
deux pays différent produisent le même hash. Pour les régions et
sous-régions, le hash n'a besoin d'être unique qu'à l'intérieur de
leur pays, pas à un niveau mondial.

Si cela venait à ce produire, la chose ne serait cependant pas
dramatique, il faudrait simplement stocker un deuxième hash (la chaine
moins un charactère, par exemple) capable de départager les deux
régions impliquées dans la collision.

## Conclusion

Nous avons un code très efficace pour regrouper les lieux par région.

Que reste-t-il à faire ?

Le plus évident, mais pas le moins fastidieux: remplir la liste des
régions, et la maintenir à jour. Ces données peuvent être ajoutées au
fur et à mesure, et le monde devrait être suffisament stable pour ne
pas changer les noms des régions tous les quatres matins.

Ensuite, comment gérer les anciennes régions ? Certains pays
disparaissent, les frontières bougent, les régions sont réformés.

Pour le moment, rien n'est prévu pour gérer les anciens noms de
région.  Comment statué dans l'article précédent, c'est la
localisation sur une carte actuelle qui nous intéressera ici. Mais la
question mérite tout de même que l'on y réfléchisse.

<a class="home-btn" href="/">Retout à l’accueil</a>
