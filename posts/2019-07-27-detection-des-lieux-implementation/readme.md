# Détection des lieux - Implémentation

_Les détails technique d'un de regrouper les lieux. Voyons comment
rester efficace en temps CPU et en consommation mémoire._

_Note : pour plus de consision, je parlais indifférement de __région__
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
devient tout de suite beaucoup plus acceptable.

Ainsi, une chaîne que l'on voudra comparé subira le m

## L'implémentation

Nous voulons produire un module capable de trouver une région à partir
d'une chaîne de caractères. Nous avons vu comment

Un programme OCaml va se charger de définir


## Les collisions de hash

Pour le moment, je n'ai pas eu de problème de collision de hash (c'est
à dire deux chaines de charactère qui seraient représentées par le
même entier une fois hachée). Il est peut probable que cela arrive,
car il faudrait que deux pays différent produisent le même hash. Pour
les régions et sous-régions, le hash n'a besoin d'être unique qu'à
l'intérieur de leur pays, pas à un niveau mondial.

Si cela venait à ce produire, la chose ne serait cependant pas
dramatique, il faudrait simplement stocker un deuxième hash (la chaine
moins un charactère, par exemple) capable de départager les deux
régions impliquées dans la collision.
