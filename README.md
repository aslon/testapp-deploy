# Dépôt de déploiement d'une équipe du homelab

Ce dépôt décrit **ce qui tourne** pour votre équipe sur le homelab : une page « Bonjour depuis le homelab » en dev,
puis en prod. Argo CD lit `deploy/<app>/dev/` et `deploy/<app>/prod/` sur `main` : une fusion sur `main` **déploie**,
sans autre geste. Votre code applicatif vit ailleurs ; ici, seulement le déploiement.

En 15 minutes : votre page en ligne sur `https://<app>-dev.alson-lab.fr`, chaque PR vérifiée contre les règles réelles
des clusters.

**Lisez d'abord la [vue d'ensemble](https://github.com/aslon/homelab-tenant-kit/blob/main/docs/vue-ensemble.md)**
(5 minutes) : à quoi sert le homelab, dev et prod, la sécurité, vos données, et les prérequis.

## Avant de commencer

L'admin du homelab vous a remis :

- votre **nom d'équipe** (minuscules et chiffres, par exemple `monequipe`) et le nom de votre **app** ;
- deux **clés de déploiement**, une par cluster ;
- l'accès à `https://argocd-dev.alson-lab.fr` (connexion « Authentik » avec votre compte GitHub).

Sur votre poste : `git`, `bash`, `perl` (présents sur macOS et Linux), et `kubectl` pour vérifier un rendu.

Pour remplacer l'exemple par **votre** app, son image doit :

- tourner **sans root** et écouter sur un **port supérieur à 1024** (les images « unprivileged » le font déjà) ;
- être construite pour `linux/amd64` et publiée sur `ghcr.io`, `docker.io`, `quay.io`, `registry.k8s.io` ou
  `rg.fr-par.scw.cloud` ;
- être désignée par son **digest** (`sha256:…`), que votre CI affiche à la poussée.

## 1. Créer votre dépôt

1. En haut de cette page : **Use this template → Create a new repository**, nommé `<équipe>-deploy`.
   **Public**, ou **privé seulement sur un compte ou une organisation dont le plan applique les règles de branche**
   (GitHub Pro, Team ou Enterprise) : sur GitHub Free, un dépôt privé accepte les règles mais ne les fait pas
   respecter, et rien n'empêcherait une fusion sans revue de partir en production.
2. Dans le nouveau dépôt : **Settings → Deploy keys → Add deploy key**, une fois par clé reçue, **sans** cocher « Allow
   write access ». Le homelab lit votre dépôt, il n'y écrit jamais.
3. **Settings → Rules → Rulesets** sur `main` : PR obligatoire (avec revue si vous êtes plusieurs), pas de
   suppression ni de force-push. Le check de la CI s'ajoute à l'étape 3, une fois qu'il a tourné une première fois.

## 2. Personnaliser

```bash
git clone git@github.com:<vous>/<équipe>-deploy.git && cd <équipe>-deploy
./init.sh <équipe> <app>        # par exemple : ./init.sh monequipe hello
git diff                        # relisez : noms, namespace <équipe>-<app>, hôtes, workflow
```

`init.sh` remplace `monequipe` et `hello` dans `deploy/` et `.github/`, et ne fait rien d'autre. Vérifiez les rendus :

```bash
kubectl kustomize deploy/<app>/dev     # namespace <équipe>-<app>, hôte <app>-dev.alson-lab.fr
kubectl kustomize deploy/<app>/prod    # même image, hôte <app>.alson-lab.fr
```

## 3. Livrer en dev

```bash
git switch -c premiere-livraison
git add -A && git commit -m "Personnalisation du modèle"
git push -u origin premiere-livraison
```

Ouvrez une PR vers `main`. En une minute environ, le check **homelab / verifier** dit `OK <app>/dev` et
`OK <app>/prod`, ou `REFUS … : <message du cluster>`.

Le check a maintenant tourné une fois : rendez-le obligatoire. **Settings → Rules → Rulesets**, règle de `main` :
« Require status checks to pass », ajoutez `homelab / verifier` (le nom exact affiché sous la PR). Ensuite seulement,
fusionnez : dans les minutes qui suivent, `https://<app>-dev.alson-lab.fr` affiche
la page, et Argo CD dev montre `<équipe>-<app>` **Synced** et **Healthy**.

La toute première livraison attend que l'admin ait déclaré votre équipe : il vous prévient.

## 4. Passer en production

`deploy/<app>/prod/` est déjà là, avec la même image qu'en dev. La première fois, **demandez la mise en production à
l'admin** : il ouvre votre hôte public et votre namespace de prod. Ensuite, une fusion sur `main` qui touche `prod/`
part en production sans autre geste.

## Au quotidien

| Je veux | Je fais |
|---|---|
| Une nouvelle version en dev | Changer `newTag` **et** `digest` dans `deploy/<app>/dev/kustomization.yaml`, PR, fusion |
| La même version en prod | PR qui recopie **les mêmes** `newTag` et `digest` dans `prod/` |
| Revenir en arrière | `git revert` de la PR, fusion |
| Changer la structure (port, variable) | D'abord un patch dans `dev/`, puis dans `base/` une fois validé : `base/` part dans les deux clusters |
| Comprendre un refus | Le message du check ou d'Argo CD, puis la [table des règles](https://github.com/aslon/homelab-tenant-kit/blob/main/docs/reference.md#les-règles) |

L'image s'écrit toujours avec son **digest** (`nom:tag@sha256:…`) : sans lui, le cluster la refuse. Votre CI de
build peut écrire `newTag` et `digest` à votre place.

## Pour aller plus loin

- **[Usage courant](https://github.com/aslon/homelab-tenant-kit/blob/main/docs/usage.md)** : comment ça marche,
  livrer une version, la CI, passer en prod, vos accès, `kubectl` en lecture sur dev, secrets (SealedSecret).
- **[Référence](https://github.com/aslon/homelab-tenant-kit/blob/main/docs/reference.md)** : règles et messages de
  refus, quotas, réseau, dépannage, et ce que le homelab ne garantit pas (à lire avant d'y mettre quoi que ce soit
  d'important).

Le check `homelab` vient de [aslon/homelab-tenant-kit](https://github.com/aslon/homelab-tenant-kit), épinglé par SHA ;
Dependabot propose chaque nouvelle version. **Vert ne veut pas dire admis** : la CI ne voit ni la compatibilité gVisor
de votre image ni le déchiffrement de vos secrets ; Argo CD reste le juge.
