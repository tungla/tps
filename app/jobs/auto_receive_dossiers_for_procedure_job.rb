class AutoReceiveDossiersForProcedureJob < ApplicationJob
  queue_as :cron

  def perform(procedure_id)
    procedure = Procedure.find_by(id: procedure_id)
    if procedure
      procedure.dossiers.state_nouveaux.update_all(state: "en_instruction", en_instruction_at: Time.now)
    end
  end
end
