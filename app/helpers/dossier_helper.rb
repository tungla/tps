module DossierHelper
  def button_or_label_class(dossier)
    if dossier.accepte?
      'accepted'
    elsif dossier.without_continuation?
      'without-continuation'
    elsif dossier.refuse?
      'refuse'
    end
  end
end
