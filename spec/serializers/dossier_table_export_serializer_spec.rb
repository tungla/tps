require 'spec_helper'

describe DossierTableExportSerializer do
  describe '#emails_accompagnateurs' do
    let(:gestionnaire){ create(:gestionnaire) }
    let(:gestionnaire2) { create :gestionnaire}
    let(:dossier) { create(:dossier) }

    subject { DossierTableExportSerializer.new(dossier).emails_accompagnateurs }

    context 'when there is no accompagnateurs' do
      it { is_expected.to eq('') }
    end

    context 'when there one accompagnateur' do
      before { gestionnaire.followed_dossiers << dossier }

      it { is_expected.to eq(gestionnaire.email) }
    end

    context 'when there is 2 followers' do
      before do
        gestionnaire.followed_dossiers << dossier
        gestionnaire2.followed_dossiers << dossier
      end

      it { is_expected.to eq "#{gestionnaire.email} #{gestionnaire2.email}" }
    end
  end
end
