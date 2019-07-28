# GWDB : les collections et les marqueurs

_Retour sur les récents changements apportés au module Gwdb :
les collections._

Dans GeneWeb, il arrive souvent de devoir itérer sur toutes les
personnes de la base. Jusqu'ici, la façon de faire était d'utiliser
une boucle `for`.

```ocaml
for i = 0 to Gwdb.nd_of_persons base - 1 do
  let p = poi base (Adef.iper_of_int i) in
  ...
done
```

Cette façon de faire induit certains problèmes :
1. Cela repose sur le fait que les identifiants des personnes dans la
  base sont des entiers qui vont de `0` à
  `nb_of_persons`. Typiquement, avec une implémentation de `Gwdb`
  basée sur un SGBD il sera compliqué de respecter ce prédicat.
2. Cela fait itérer sur les personnes supprimées de la base. Dans
  l'implémentation de base de `Gwdb`, les personnes sont stockées dans
  un tableau, et leur identifiant unique est leur index dans ce
  tableau. Quand une personne est supprimée, elle n'est pas réellement
  retirée de ce tableau, ses informations sont seulement
  écrasées. Nous allons donc itérer sur des personnes supprimées (des
  personnes vides).

Ces remarques sont vraies également pour les familles, et notamment le
deuxième point, comme le montre la nécessiter d'utiliser le test
`is_deleted_damily` avant d'effectuer une opération sur une famille
dans une boucle.

## Les collections

Afin de donner plus de liberté aux implémentations de `Gwdb`, ainsi
qu'une plus grande sécurité dans le reste du code de GeneWeb (ne pas
avoir à se soucier de savoir si la personne/famille sur qui on itère
existe toujours ou non), une couche d'abstraction a été ajouté à ces
parcours de listes : le module `Collection`.

```ocaml
module Collection : sig
  type 'a t
  val length : 'a t -> int
  val map : ('a -> 'b) -> 'a t -> 'b t
  val iter : ('a -> unit) -> 'a t -> unit
  val iteri : (int -> 'a -> unit) -> 'a t -> unit
  val fold : ('a -> 'b -> 'a) -> 'a -> 'b t -> 'a
  val fold_until : ('a -> bool) -> ('a -> 'b -> 'a) -> 'a -> 'b t -> 'a
  val iterator : 'a t -> (unit -> 'a option)
end

val ipers : base -> iper Collection.t
val persons : base -> person Collection.t
val ifams : base -> ifam Collection.t
val families : base -> family Collection.t
```

Chaque module implémentant `Gwdb` doit donc, en plus de toutes les
fonctions de lecture et écriture des personnes/familles, fournir
également un module `Collection`, qui permet aux algorithmes de
GeneWeb d'agir sur l'ensemble des personnes/familles de la base, sans
avoir à se soucier de leur implémentation.

Il revient donc au module `Gwdb`, et à lui seulement de faire le tri
sur les données parcourables. Exit le dangereux oubli de
`is_deleted_damily`.

## Les marqueurs

Les algorithmes parcourant une collection d'élément ont souvent besoin
de stocker des informations sur ces éléments pendant leurs
itérations. Par exemple, le calcul de consanguinité marque les
personnes déjà traitées, afin de ne pas faire le travail plusieurs
fois, ou les personnes en cours de traitement, afin de lever une
erreur si l'arbre contient une boucle.

Pour répondre à ce besoin, une implémentation de `Gwdb` doit donc
fournir un moyen de retenir des informations sur les éléments d'une
collection.

```ocaml
module Marker : sig
  type ('k, 'v) t
  val get : ('k, 'v) t -> 'k -> 'v
  val set : ('k, 'v) t -> 'k -> 'v -> unit
end

val iper_marker : iper Collection.t -> 'a -> (iper, 'a) Marker.t
val ifam_marker : ifam Collection.t -> 'a -> (ifam, 'a) Marker.t
```

Il s'agit du sous-module `Marker`, qui permet d'associer un marqueur à
une collection de `iper` ou de `ifam`.

## Changement de la façon d'écrire les algorithmes

Voici la fonction de vérification de boucle dans un arbre basée sur
une représentation des personnes sous forme de tableau continu.

```ocaml
let rec noloop_aux base error tab i =
  match tab.(i) with
  | NotVisited ->
    begin match get_parents (poi base (Adef.iper_of_int i)) with
        Some ifam ->
        let fam = foi base ifam in
        let fath = get_father fam in
        let moth = get_mother fam in
        tab.(i) <- BeingVisited;
        noloop_aux base error tab (Adef.int_of_iper fath);
        noloop_aux base error tab (Adef.int_of_iper moth)
      | None -> ()
    end;
    tab.(i) <- Visited
  | BeingVisited -> error (OwnAncestor (poi base (Adef.iper_of_int i)))
  | Visited -> ()

let check_noloop base error =
  let tab = Array.make (nb_of_persons base) NotVisited in
  for i = 0 to nb_of_persons base - 1 do noloop_aux base error tab i done
```

La même chose, basée sur une itération sur une `Collection.t`.

```ocaml
let rec noloop_aux base error tab i =
  match Gwdb.Marker.get tab i with
  | NotVisited ->
    begin match get_parents (poi base i) with
      | Some ifam ->
        let fam = foi base ifam in
        let fath = get_father fam in
        let moth = get_mother fam in
        Gwdb.Marker.set tab i BeingVisited ;
        noloop_aux base error tab fath ;
        noloop_aux base error tab moth
      | None -> ()
    end ;
    Gwdb.Marker.set tab i Visited
  | BeingVisited -> error (OwnAncestor (poi base i))
  | Visited -> ()

let check_noloop base error =
  let persons = Gwdb.ipers base in
  let tab = Gwdb.iper_marker persons NotVisited in
  Gwdb.Collection.iter (noloop_aux base error tab) perso
```
