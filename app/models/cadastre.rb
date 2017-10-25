class Cadastre < ActiveRecord::Base
  belongs_to :dossier, touch: true

  def geometry
    JSON.parse(read_attribute(:geometry))
  end
end
