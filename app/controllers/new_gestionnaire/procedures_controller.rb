module NewGestionnaire
  class ProceduresController < GestionnaireController
    before_action :ensure_ownership!, except: [:index]
    before_action :redirect_to_avis_if_needed, only: [:index]

    ITEMS_PER_PAGE = 25

    def index
      @procedures = current_gestionnaire.procedures.order(archived_at: :desc, published_at: :desc)

      dossiers = current_gestionnaire.dossiers
      @dossiers_count_per_procedure = dossiers.all_state.group(:procedure_id).reorder(nil).count
      @dossiers_a_suivre_count_per_procedure = dossiers.without_followers.en_cours.group(:procedure_id).reorder(nil).count
      @dossiers_archived_count_per_procedure = dossiers.archived.group(:procedure_id).count
      @dossiers_termines_count_per_procedure = dossiers.termine.group(:procedure_id).reorder(nil).count

      @followed_dossiers_count_per_procedure = current_gestionnaire
        .followed_dossiers
        .en_cours
        .where(procedure: @procedures)
        .group(:procedure_id)
        .reorder(nil)
        .count

      @notifications_count_per_procedure = current_gestionnaire.notifications_count_per_procedure
    end

    def show
      @procedure = procedure

      @current_filters = current_filters
      @available_fields_to_filters = available_fields_to_filters
      @displayed_fields = procedure_presentation.displayed_fields
      @displayed_fields_values = displayed_fields_values

      @a_suivre_dossiers = procedure
        .dossiers
        .includes(:user)
        .without_followers
        .en_cours

      @followed_dossiers = current_gestionnaire
        .followed_dossiers
        .includes(:user, :notifications)
        .where(procedure: @procedure)
        .en_cours

      @followed_dossiers_id = current_gestionnaire
        .followed_dossiers
        .where(procedure: @procedure)
        .pluck(:id)

      @termines_dossiers = procedure.dossiers.includes(:user).termine

      @all_state_dossiers = procedure.dossiers.includes(:user).all_state

      @archived_dossiers = procedure.dossiers.includes(:user).archived

      @dossiers = case statut
      when 'a-suivre'
        @a_suivre_dossiers
      when 'suivis'
        @followed_dossiers
      when 'traites'
        @termines_dossiers
      when 'tous'
        @all_state_dossiers
      when 'archives'
        @archived_dossiers
      end

      sorted_ids = sorted_ids(@dossiers)

      if @current_filters.count > 0
        filtered_ids = filtered_ids(@dossiers)
        filtered_sorted_ids = sorted_ids.select { |id| filtered_ids.include?(id) }
      else
        filtered_sorted_ids = sorted_ids
      end

      page = params[:page].present? ? params[:page] : 1

      filtered_sorted_paginated_ids = Kaminari
        .paginate_array(filtered_sorted_ids)
        .page(page)
        .per(ITEMS_PER_PAGE)

      @dossiers = @dossiers.where(id: filtered_sorted_paginated_ids)

      eager_load_displayed_fields

      @dossiers = @dossiers.sort_by { |d| filtered_sorted_paginated_ids.index(d.id) }

      kaminarize(page, filtered_sorted_ids.count)
    end

    def update_displayed_fields
      values = params[:values]

      if values.nil?
        values = []
      end

      fields = values.map do |value|
        table, column = value.split("/")

        c = procedure.fields.find do |field|
          field['table'] == table && field['column'] == column
        end

        c.to_json
      end

      procedure_presentation.update_attributes(displayed_fields: fields)

      current_sort = procedure_presentation.sort
      if !values.include?("#{current_sort['table']}/#{current_sort['column']}")
        procedure_presentation.update_attributes(sort: Procedure.default_sort)
      end

      redirect_back(fallback_location: procedure_url(procedure))
    end

    def update_sort
      current_sort = procedure_presentation.sort
      table = params[:table]
      column = params[:column]

      if table == current_sort['table'] && column == current_sort['column']
        order = current_sort['order'] == 'asc' ? 'desc' : 'asc'
      else
        order = 'asc'
      end

      sort = {
        'table' => table,
        'column' => column,
        'order' => order
      }.to_json

      procedure_presentation.update_attributes(sort: sort)

      redirect_back(fallback_location: procedure_url(procedure))
    end

    def add_filter
      filters = procedure_presentation.filters
      table, column = params[:field].split('/')
      label = procedure.fields.find { |c| c['table'] == table && c['column'] == column }['label']

      filters[statut] << {
        'label' => label,
        'table' => table,
        'column' => column,
        'value' => params[:value]
      }

      procedure_presentation.update_attributes(filters: filters.to_json)

      redirect_back(fallback_location: procedure_url(procedure))
    end

    def remove_filter
      filters = procedure_presentation.filters
      filter_to_remove = current_filters.find do |filter|
        filter['table'] == params[:table] && filter['column'] == params[:column]
      end

      filters[statut] = filters[statut] - [filter_to_remove]

      procedure_presentation.update_attributes(filters: filters.to_json)

      redirect_back(fallback_location: procedure_url(procedure))
    end

    def download_dossiers
      export = procedure.generate_export
      filename = "dossiers_#{procedure.procedure_path.path}_#{Time.now.strftime('%Y-%m-%d_%H-%M')}"

      respond_to do |format|
        format.csv { send_data(SpreadsheetArchitect.to_csv(data: export[:data], headers: export[:headers]), filename: "#{filename}.csv") }
        format.xlsx { send_data(SpreadsheetArchitect.to_xlsx(data: export[:data], headers: export[:headers]), filename: "#{filename}.xlsx") }
        format.ods { send_data(SpreadsheetArchitect.to_ods(data: export[:data], headers: export[:headers]), filename: "#{filename}.ods") }
      end
    end

    private

    def statut
      @statut ||= params[:statut].present? ? params[:statut] : 'a-suivre'
    end

    def procedure
      Procedure.find(params[:procedure_id])
    end

    def ensure_ownership!
      if !procedure.gestionnaires.include?(current_gestionnaire)
        flash[:alert] = "Vous n'avez pas accès à cette procédure"
        redirect_to root_path
      end
    end

    def redirect_to_avis_if_needed
      if current_gestionnaire.procedures.count == 0 && current_gestionnaire.avis.count > 0
        redirect_to avis_index_path
      end
    end

    def procedure_presentation
      @procedure_presentation ||= current_gestionnaire.procedure_presentation_for_procedure_id(params[:procedure_id])
    end

    def displayed_fields_values
      procedure_presentation.displayed_fields.map do |field|
        "#{field['table']}/#{field['column']}"
      end
    end

    def filtered_ids(dossiers)
      current_filters.map do |filter|
        case filter['table']
        when 'self'
          dossiers.where("? LIKE ?", filter['column'], "%#{filter['value']}%")

        when 'france_connect_information'
          dossiers
            .includes(user: :france_connect_information)
            .where("? LIKE ?", "france_connect_informations.#{filter['column']}", "%#{filter['value']}%")

        when 'type_de_champ', 'type_de_champ_private'
          relation = filter['table'] == 'type_de_champ' ? :champs : :champs_private
          dossiers
            .includes(relation)
            .where("champs.type_de_champ_id = ?", filter['column'].to_i)
            .where("champs.value LIKE ?", "%#{filter['value']}%")

        when 'user', 'etablissement', 'entreprise'
          dossiers
            .includes(filter['table'])
            .where("#{filter['table'].pluralize}.#{filter['column']} LIKE ?", "%#{filter['value']}%")

        end.pluck(:id)
      end.reduce(:&)
    end

    def sorted_ids(dossiers)
      table = procedure_presentation.sort['table']
      column = procedure_presentation.sort['column']
      order = procedure_presentation.sort['order']
      includes = ''
      where = ''

      sorted_ids = nil

      case table
      when 'notifications'
        dossiers_id_with_notification = current_gestionnaire.notifications_for_procedure(procedure)
        if order == 'desc'
          sorted_ids = dossiers_id_with_notification + (dossiers.order('dossiers.updated_at desc').ids - dossiers_id_with_notification)
        else
          sorted_ids = (dossiers.order('dossiers.updated_at asc').ids - dossiers_id_with_notification) + dossiers_id_with_notification
        end
      when 'self'
        order = "dossiers.#{column} #{order}"
      when'france_connect_information'
        includes = { user: :france_connect_information }
        order = "france_connect_informations.#{column} #{order}"
      when 'type_de_champ', 'type_de_champ_private'
        includes = table == 'type_de_champ' ? :champs : :champs_private
        where = "champs.type_de_champ_id = #{column.to_i}"
        order = "champs.value #{order}"
      else
        includes = table
        order = "#{table.pluralize}.#{column} #{order}"
      end

      if sorted_ids.nil?
        sorted_ids = dossiers.includes(includes).where(where).order(Dossier.sanitize_for_order(order)).pluck(:id)
      end

      sorted_ids
    end

    def current_filters
      @current_filters ||= procedure_presentation.filters[statut]
    end

    def available_fields_to_filters
      current_filters_fields_ids = current_filters.map do |field|
        "#{field['table']}/#{field['column']}"
      end

      procedure.fields_for_select.reject do |field|
        current_filters_fields_ids.include?(field[1])
      end
    end

    def eager_load_displayed_fields
      @displayed_fields
        .reject { |field| field['table'] == 'self' }
        .group_by do |field|
          if ['type_de_champ', 'type_de_champ_private'].include?(field['table'])
            'type_de_champ_group'
          else
            field['table']
          end
        end.each do |group_key, fields|
          case group_key
          when'france_connect_information'
            @dossiers = @dossiers.includes({ user: :france_connect_information })
          when 'type_de_champ_group'
            if fields.any? { |field| field['table'] == 'type_de_champ' }
              @dossiers = @dossiers.includes(:champs).references(:champs)
            end

            if fields.any? { |field| field['table'] == 'type_de_champ_private' }
              @dossiers = @dossiers.includes(:champs_private).references(:champs_private)
            end

            where_conditions = fields.map do |field|
              "champs.type_de_champ_id = #{field['column']}"
            end.join(" OR ")

            @dossiers = @dossiers.where(where_conditions)
          else
            @dossiers = @dossiers.includes(fields.first['table'])
          end
        end
    end

    def kaminarize(current_page, total)
      @dossiers.instance_eval <<-EVAL
        def current_page
          #{current_page}
        end
        def total_pages
          (#{total} / #{ITEMS_PER_PAGE}.to_f).ceil
        end
        def limit_value
          #{ITEMS_PER_PAGE}
        end
        def first_page?
          current_page == 1
        end
        def last_page?
          current_page == total_pages
        end
EVAL
    end
  end
end
