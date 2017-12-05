namespace :'2017_12_04_translate_dossier_state_to_french' do
  task brouillon: :environment do
    Dossier.unscoped.where(state: 'draft').update_all(state: 'brouillon')
  end

  task en_construction: :environment do
    Dossier.unscoped.where(state: 'initiated').update_all(state: 'en_construction')
  end

  task en_instruction: :environment do
    Dossier.unscoped.where(state: 'received').update_all(state: 'en_instruction')
  end

  task accepte: :environment do
    Dossier.unscoped.where(state: 'closed').update_all(state: 'accepte')
  end

  task refuse: :environment do
    Dossier.unscoped.where(state: 'refused').update_all(state: 'refuse')
  end

  task sans_suite: :environment do
    Dossier.unscoped.where(state: 'without_continuation').update_all(state: 'sans_suite')
  end

  task all: %i(brouillon en_construction en_instruction accepte refuse sans_suite) do
  end
end