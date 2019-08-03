# Détection des lieux

_Implémentation d'un module capable de regrouper les lieux par pays et
régions_

## État des lieux

Le mode `m=PS` permet d'afficher la liste des lieux de l'arbre.
Évidemment, la liste de tous les lieux de l'arbre devient vite confuse
à la lecture, c'est pourquoi GeneWeb tente un regroupement. La façon
de faire est simple, et à vrai dire **trop** simple. Le texte est
découpé sur les virgules, et on obtient alors une liste de termes. Les
lieux qui ont leur dernier terme en commun (qui est considéré comme le
moins précis) sont regroupés sous ce terme.

C'est ainsi qu'on se retrouve avec des listes ayant peu de sens.  Les
lieux _Laon, 02_, _Laon, 02408, Aisne_ et _Laon, Aisne, FRANCE_ se
retrouve classé dans trois catégories différentes : _02_, _Aisne_ et
_FRANCE_.

## Les solutions existantes ?

Je voulais éviter les services en ligne. Être dépendant d'une
connexion internet pour le bon fonctionnement d'un logiciel n'est pas
une décision à prendre à la légère. Bien sûr, il est possible de
dépendre d'un service web et d'utiliser un cache du côté GeneWeb pour
continuer à fonctionner hors ligne.

J'ai regardé du côté de GeoNames, et j'ai trouvé les données beaucoup
trop fournies pour l'usage que je comptais en faire.

Rien que l'export des données de la France fait 6Mo. Une granularité
qui descend jusqu'à la ville me semble superflue dans notre cas. Le
département (ou équivalent) est, à mon avis, suffisamment précis.

Comme GeoName, les autres bases de données disponibles nécessitent un
tri et une sélection si l'on cherche à mettre en place une solution
simple et à moindre coût pour ce qui est du volume de données
nécessaires au fonctionnement.

Ces bases externes peuvent aussi entrainer l'ajout de nombreuses
dépendances, posent la question de la disponibilité sur toutes les
plateformes, de la facilité d'installation, de maintenance, et de la
stabilité sur un temps long du format de données utilisé.

## La solution maison

Le but ici n'est pas de savoir placer un point sur une carte grâce a
des coordonées GPS (c'est un fonctionnalité souhaitable, mais c'est
autre chose), mais plus de réussir à avoir une page `m=PS` plus
utilisable que l'état actuel des choses.

J'ai mis en place trois niveaux de division : `country`, `region` et
`subregion` (e.g. en France : le pays, la région, le département).

### Découper la chaîne de caractère pour extraire chaque partie

Ici, la fonction de découpage est relativement simple. Du contenu
séparé du reste par une virgule ou un point-virgule représente un
sous-partie, du contenu écrit entre parenthèses ou crochets représente
un commentaire attaché à une sous-partie (potentiellement vide).

La notation `[Lieu-dit] - Ville`, utilisé dans GeneWeb pour renseigner
les lieux-dits. Ici, `[Lieu-dit] - Ville` ne sera pas découpé mais
représentera une seule sous-partie de la chaine.

### Représentation mémoire

Techniquement parlant, les pays/régions/départements sont simplement
représentés par des types somme.

Étant donné qu'il s'agit de variant sans arguments, OCaml limite le
nombre de variant dans les types à `size of the native integer`.  Dans
le pire des cas (plateforme 32 bits, cela donne 1,073,741,823, ce qui
devrait suffire à couvrir l'ensemble des sous-régions du monde...

> The only limit on the number of variants without parameters is the
> size of the native integer (either 31 or 63 bits [RWO - Memory
> Representation of
> Values](https://dev.realworldocaml.org/runtime-memory-layout.html)

### Convertir une chaine de caractères en pays/région/département

Ici, nous avons besoin de définir toutes les chaînes de caractères qui
vont correspondre à un variant.

e.g.
```ocaml
   ;United_Kingdom,[|"UK";"Royaume-Uni";"United Kingdom"|]
   ;United_States,[|"US";"USA";"États-Unis";"United States"|]
```

```ocaml
   ;FR_Aisne,[|"Aisne";"02"|]
   ;FR_Allier,[|"Allier";"03"|]
   ;FR_Alpes_de_Haute_Provence,[|"Alpes-de-Haute-Provence";"04"|]
```

Pour mes tests, j'ai entré toutes les valeurs utilisées à la main,
mais on peut bien sûr penser mettre en place une extraction
automatique de ces données depuis des sources réunissant déjà les
appellations différentes utilisées pour un même variant.

Une fois que l'on a ces correspondances, le reste va tout seul.

On commence par déterminer le pays, étape cruciale pour le bon
déroulement du reste de l'identification. En cas d'échec, un pays par
défaut est attribué (configurable pour chaque base). On peut supposer
que l'absence du pays indique que le lieu se trouve dans le pays
d'origine du sosa 0.

Ensuite, suivant la position dans la liste des sous-parties, ou la
forme de la donnée, on essaye de faire correspondre les autres parties
à une région ou un département. Les parties qui ne correspondent à
aucun des deux types seront utilisé comme adresse ou comme ville, ou
tout simplement jeté si ces informations sont déjà renseignées ou
qu'une information est en double (e.g. `Aisne (02)` : `Aisne` et `02`
correspondent à la même information.

### Quelques ajustements à la main

Enfin, une fonction de finalisation permet de remplir de données
manquantes à partir de ce qu'on a pu trouver. Par exemple, si la
région n'est pas renseignée, on peut la retrouver si le département
l'est. Si le département est `FR_Paris`, alors la ville est
forcément `Paris`.
