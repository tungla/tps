class DossierService

  def initialize dossier, siret, france_connect_information
    @dossier = dossier
    @siret = siret
    @france_connect_information = france_connect_information
  end

  def dossier_informations!
    entreprise_thread = Thread.new {
      @entreprise_adapter = SIADE::EntrepriseAdapter.new(DossierService.siren @siret)

      @dossier.create_entreprise(@entreprise_adapter.to_params)
    }

    etablissement_thread = Thread.new {
      @etablissement_adapter = SIADE::EtablissementAdapter.new(@siret)

      @dossier.create_etablissement(@etablissement_adapter.to_params)
    }

    rna_thread = Thread.new {
      @rna_adapter = SIADE::RNAAdapter.new(@siret)

      sleep(0.1) while entreprise_thread.alive?

      @dossier.entreprise.create_rna_information(@rna_adapter.to_params)
    }

    exercices_thread = Thread.new {
      @exercices_adapter = SIADE::ExercicesAdapter.new(@siret)

      sleep(0.1) while etablissement_thread.alive?

      @dossier.etablissement.exercices.create(@exercices_adapter.to_params)
    }

    sleep(0.1) while entreprise_thread.alive? ||
        etablissement_thread.alive? ||
        rna_thread.alive? ||
        exercices_thread.alive?

    @dossier.update_attributes(mandataire_social: mandataire_social?(@entreprise_adapter.mandataires_sociaux))
    @dossier.etablissement.update_attributes(entreprise: @dossier.entreprise)

    @dossier
  end


  def self.siren siret
    siret[0..8]
  end

  private

  def mandataire_social? mandataires_list
    unless @france_connect_information.nil?

      mandataires_list.each do |mandataire|
        return true if mandataire[:nom].upcase == @france_connect_information.family_name.upcase &&
            mandataire[:prenom].upcase == @france_connect_information.given_name.upcase &&
            mandataire[:date_naissance_timestamp] == @france_connect_information.birthdate.to_time.to_i
      end
    end

    false
  end
end