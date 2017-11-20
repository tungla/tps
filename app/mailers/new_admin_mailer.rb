class NewAdminMailer < ApplicationMailer
  def new_admin_email admin
    @admin = admin

    mail(to: 'tech@tps.apientreprise.fr',
         subject: "Création d'un compte Admin demarches-publiques.fr")
  end
end
