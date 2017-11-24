module ChampHelper
  def value(champ)
    value = champ.value

    if value.blank?
      value
    else
      case champ.type_champ
      when "date"
        Date.parse(value).strftime("%d/%m/%Y")
      when "checkbox", "engagement"
        value == 'on' ? 'Oui' : 'Non'
      when 'yes_no'
        value == 'true' ? 'Oui' : 'Non'
      when 'multiple_drop_down_list'
        JSON.parse(value).join(', ')
      else
        value
      end
    end
  end
end
