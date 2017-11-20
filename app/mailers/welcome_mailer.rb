class WelcomeMailer < ApplicationMailer
  def welcome_email user
    @user = user

    mail(to: user.email,
         subject: "Création de votre compte demarches-publiques.fr")
  end
end
