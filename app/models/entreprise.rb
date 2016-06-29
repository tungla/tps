class Entreprise < ActiveRecord::Base
  belongs_to :dossier
  has_one :etablissement, dependent: :destroy
  has_one :rna_information, dependent: :destroy
end
