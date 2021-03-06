class Gestionnaire < ActiveRecord::Base
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :trackable, :validatable

  has_and_belongs_to_many :administrateurs

  has_one :preference_smart_listing_page, dependent: :destroy

  has_many :assign_to, dependent: :destroy
  has_many :procedures, -> { publiees_ou_archivees }, through: :assign_to
  has_many :dossiers, -> { state_not_brouillon }, through: :procedures
  has_many :followed_dossiers, through: :follows, source: :dossier
  has_many :follows
  has_many :preference_list_dossiers
  has_many :avis

  after_create :build_default_preferences_list_dossier
  after_create :build_default_preferences_smart_listing_page

  include CredentialsSyncableConcern

  def procedure_filter
    procedure_id = self[:procedure_filter]
    if procedures.find_by(id: procedure_id).present?
      procedure_id
    else
      self.update_column(:procedure_filter, nil)
      nil
    end
  end

  def can_view_dossier?(dossier_id)
    avis.where(dossier_id: dossier_id).any? ||
      dossiers.where(id: dossier_id).any?
  end

  def follow(dossier)
    return if follow?(dossier)

    followed_dossiers << dossier
  end

  def unfollow(dossier)
    followed_dossiers.delete(dossier)
  end

  def follow?(dossier)
    followed_dossiers.include?(dossier)
  end

  def assigned_on_procedure?(procedure_id)
    procedures.find_by(id: procedure_id).present?
  end

  def build_default_preferences_list_dossier procedure_id=nil
    PreferenceListDossier.available_columns_for(procedure_id).each do |table|
      table.second.each do |column|
        if valid_couple_table_attr? table.first, column.first
          PreferenceListDossier.create(
              libelle: column.second[:libelle],
              table: column.second[:table],
              attr: column.second[:attr],
              attr_decorate: column.second[:attr_decorate],
              bootstrap_lg: column.second[:bootstrap_lg],
              order: nil,
              filter: nil,
              procedure_id: procedure_id,
              gestionnaire: self
          )
        end
      end
    end
  end

  def build_default_preferences_smart_listing_page
    PreferenceSmartListingPage.create(page: 1, procedure: nil, gestionnaire: self, liste: 'a_traiter')
  end

  def notifications
    Notification.where(already_read: false, dossier_id: follows.pluck(:dossier_id)).order("updated_at DESC")
  end

  def notifications_for procedure
    procedure_ids = followed_dossiers.pluck(:procedure_id)

    if procedure_ids.include?(procedure.id)
      return followed_dossiers.where(procedure_id: procedure.id)
                 .inject(0) do |acc, dossier|
        acc += dossier.notifications.where(already_read: false).count
      end
    end
    0
  end

  def dossiers_with_notifications_count_for_procedure(procedure)
    followed_dossiers_id = followed_dossiers.where(procedure: procedure).pluck(:id)
    Notification.unread.where(dossier_id: followed_dossiers_id).select(:dossier_id).distinct(:dossier_id).count
  end

  def notifications_count_per_procedure
    followed_dossiers
      .joins(:notifications)
      .where(notifications: { already_read: false })
      .group('procedure_id')
      .count
  end

  def dossiers_with_notifications_count
    notifications.pluck(:dossier_id).uniq.count
  end

  def last_week_overview
    start_date = DateTime.now.beginning_of_week

    active_procedure_overviews = procedures
                            .publiees
                            .map { |procedure| procedure.procedure_overview(start_date) }
                            .select(&:had_some_activities?)

    if active_procedure_overviews.count == 0
      nil
    else
      {
        start_date: start_date,
        procedure_overviews: active_procedure_overviews,
      }
    end
  end

  def procedure_presentation_for_procedure_id(procedure_id)
    assign_to.find_by(procedure_id: procedure_id).procedure_presentation_or_default
  end

  def notifications_for_dossier(dossier)
    follow = Follow
      .includes(dossier: [:champs, :avis, :commentaires])
      .find_by(gestionnaire: self, dossier: dossier)

    if follow.present?
      #retirer le seen_at.present? une fois la contrainte de presence en base (et les migrations ad hoc)
      champs_publiques = follow.demande_seen_at.present? &&
        follow.dossier.champs.updated_since?(follow.demande_seen_at).any?

      pieces_justificatives = follow.demande_seen_at.present? &&
        follow.dossier.pieces_justificatives.updated_since?(follow.demande_seen_at).any?

      demande = champs_publiques || pieces_justificatives

      annotations_privees = follow.annotations_privees_seen_at.present? &&
        follow.dossier.champs_private.updated_since?(follow.annotations_privees_seen_at).any?

      avis_notif = follow.avis_seen_at.present? &&
        follow.dossier.avis.updated_since?(follow.avis_seen_at).any?

      messagerie = follow.messagerie_seen_at.present? &&
        dossier.commentaires
        .where.not(email: 'contact@tps.apientreprise.fr')
        .updated_since?(follow.messagerie_seen_at).any?

      annotations_hash(demande, annotations_privees, avis_notif, messagerie)
    else
      annotations_hash(false, false, false, false)
    end
  end

  def notifications_for_procedure(procedure)
    dossiers = procedure.dossiers.en_cours.followed_by(self)

    dossiers_id_with_notifications(dossiers)
  end

  def notifications_per_procedure
    dossiers = Dossier.en_cours.followed_by(self)

    Dossier.where(id: dossiers_id_with_notifications(dossiers)).group(:procedure_id).count
  end

  def mark_tab_as_seen(dossier, tab)
    attributes = {}
    attributes["#{tab}_seen_at"] = DateTime.now
    Follow.where(gestionnaire: self, dossier: dossier).update_all(attributes)
  end

  private

  def valid_couple_table_attr? table, column
    couples = [{
                   table: :dossier,
                   column: :dossier_id
               }, {
                   table: :procedure,
                   column: :libelle
               }, {
                   table: :etablissement,
                   column: :siret
               }, {
                   table: :entreprise,
                   column: :raison_sociale
               }, {
                   table: :dossier,
                   column: :state
               }]

    couples.include?({table: table, column: column})
  end

  def annotations_hash(demande, annotations_privees, avis, messagerie)
    {
      demande: demande,
      annotations_privees: annotations_privees,
      avis: avis,
      messagerie: messagerie
    }
  end

  def dossiers_id_with_notifications(dossiers)
    updated_demandes = dossiers
      .joins(:champs)
      .where('champs.updated_at > follows.demande_seen_at')

    updated_pieces_justificatives = dossiers
      .joins(:pieces_justificatives)
      .where('pieces_justificatives.updated_at > follows.demande_seen_at')

    updated_annotations = dossiers
      .joins(:champs_private)
      .where('champs.updated_at > follows.annotations_privees_seen_at')

    updated_avis = dossiers
      .joins(:avis)
      .where('avis.updated_at > follows.avis_seen_at')

    updated_messagerie = dossiers
      .joins(:commentaires)
      .where('commentaires.updated_at > follows.messagerie_seen_at')
      .where.not(commentaires: { email: 'contact@tps.apientreprise.fr' })

    [updated_demandes,
     updated_pieces_justificatives,
     updated_annotations,
     updated_avis,
     updated_messagerie].map { |query| query.distinct.ids }.flatten.uniq
  end
end
