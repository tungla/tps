# TPS - Téléprocédures Simplifiées

## Context

Téléprocédures Simplifiées, ou TPS pour les intimes, est une plateforme 100 % web et 0 % email, conçue afin de répondre au besoin urgent de l'État d'appliquer la directive sur le 100 % démat' à l'horizon 2018 pour les procédures administratives.


## Dépendances

### Tous environnements

- postgresql

### Développement

- Mailcatcher : `gem install mailcatcher`

### Tests

- PhantomJS


## Initialisation de l'environnement de développement

Afin d'initialiser l'environnement de développement, éxécutez la commande suivante :

    bundle install


## Création de la base de données

Les informations nécessaire à l'initialisation de la base doivent être pré-configurées à la main grâce à la procédure suivante :

    su - postgres
    psql
    > create user tps_development with password 'tps_development' superuser;
    > create user tps_test with password 'tps_test' superuser;
    > \q

Afin de générer la BDD de l'application, il est nécessaire d'éxécuter les commandes suivantes :

    # Create and load the schema for both databases
    rake db:create db:schema:load

    # Migrate the development database and then the test database
    rake db:migrate
    rake db:migrate RAILS_ENV=test


## Création des comptes initiaux

    rails c
    > email = "<votre email>"
    > password = "<votre mot de passe>"
    > Administration.create(email: email, password: password)
    > Administrateur.create(email: email, password: password)
    > Gestionnaire.create(email: email, password: password)
    > User.create(email: email, password: password)


## Lancement de l'application

    bin/delayed_job run
    mailcatcher -f
    rails s

## Programmation des jobs

    AutoArchiveProcedureJob.set(cron: "* * * * *").perform_later
    WeeklyOverviewJob.set(cron: "0 8 * * 0").perform_later
    AutoReceiveDossiersForProcedureJob.set(cron: "* * * * *").perform_later(procedure_declaratoire_id)

## Exécution des tests (RSpec)

Pour exécuter les tests de l'application, plusieurs possibilités :

- Lancer tous les tests

        rake spec
        rspec

- Lancer un test en particulier

        rake spec SPEC=file_path/file_name_spec.rb:line_number
        rspec file_path/file_name_spec.rb:line_number

- Lancer tous les tests d'un fichier

        rake spec SPEC=file_path/file_name_spec.rb
        rspec file_path/file_name_spec.rb

## Linting

- Faire tourner RuboCop : `bundle exec rubocop -R`
- Faire tourner Brakeman : `bundle exec brakeman -z`
- Linter les fichiers HAML : `bundle exec haml-lint app/views/`
- Linter les fichiers SCSS : `bundle exec scss-lint app/assets/stylesheets/`

## Déploiement

- Tout nouveau commit ajouté à la branche `dev` est automatiquement déployé [en intégration](https://tps-dev.apientreprise.fr/)
- Tout nouveau commit ajouté à la branche `master` est automatiquement déployé [en production](https://tps.apientreprise.fr/)

## Régénérer les binstubs

    bundle binstub railties --force
    rake rails:update:bin
