require 'rails_helper'

RSpec.describe AutoReceiveDossiersForProcedureJob, type: :job do
  describe "perform" do
    let(:date) { Time.utc(2017, 9, 1, 10, 5, 0) }

    before { Timecop.freeze(date) }
    after { Timecop.return }

    subject { AutoReceiveDossiersForProcedureJob.new.perform(procedure_id) }

    context "with some dossiers" do
      let(:nouveau_dossier1) { create(:dossier, :initiated) }
      let(:nouveau_dossier2) { create(:dossier, :initiated, procedure: nouveau_dossier1.procedure) }
      let(:dossier_recu) { create(:dossier, :received, procedure: nouveau_dossier2.procedure) }
      let(:dossier_draft) { create(:dossier, procedure: dossier_recu.procedure) }
      let(:procedure_id) { dossier_draft.procedure_id }

      it do
        subject
        expect(nouveau_dossier1.reload.received?).to be true
        expect(nouveau_dossier1.reload.received_at).to eq(date)

        expect(nouveau_dossier2.reload.received?).to be true
        expect(nouveau_dossier2.reload.received_at).to eq(date)

        expect(dossier_recu.reload.received?).to be true
        expect(dossier_recu.reload.received_at).to eq(date)

        expect(dossier_draft.reload.draft?).to be true
        expect(dossier_draft.reload.received_at).to eq(nil)
      end
    end
  end
end
