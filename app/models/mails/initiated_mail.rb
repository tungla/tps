module Mails
  class InitiatedMail < ApplicationRecord
    include MailTemplateConcern

    SLUG = "initiated_mail"
    TEMPLATE_NAME = "mails/initiated_mail"
    DISPLAYED_NAME = 'Accusé de réception'
    DEFAULT_OBJECT = 'Votre dossier demarches-publiques.fr nº --numero_dossier-- a bien été reçu'
    ALLOWED_TAGS = [TAG_NUMERO_DOSSIER, TAG_LIEN_DOSSIER, TAG_LIBELLE_PROCEDURE]
  end
end
