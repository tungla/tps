require 'spec_helper'

describe MailTemplateConcern do
  let(:dossier) { create :dossier }
  let(:dossier2) { create :dossier }
  let(:initiated_mail) { Mails::InitiatedMail.default }

  shared_examples "can replace tokens in template" do
    describe 'with no token to replace' do
      let(:template) { '[demarches-publiques.fr] rien à remplacer' }
      it do
        is_expected.to eq("[demarches-publiques.fr] rien à remplacer")
      end
    end

    describe 'with one token to replace' do
      let(:template) { '[demarches-publiques.fr] Dossier : --numero_dossier--' }
      it do
        is_expected.to eq("[demarches-publiques.fr] Dossier : #{dossier.id}")
      end
    end

    describe 'with multiples tokens to replace' do
      let(:template) { '[demarches-publiques.fr] --numero_dossier-- --libelle_procedure-- --lien_dossier--' }
      it do
        expected =
          "[demarches-publiques.fr] #{dossier.id} #{dossier.procedure.libelle} " +
          "<a target=\"_blank\" href=\"http://localhost:3000/users/dossiers/#{dossier.id}/recapitulatif\">http://localhost:3000/users/dossiers/#{dossier.id}/recapitulatif</a>"

        is_expected.to eq(expected)
      end
    end
  end

  describe '.object_for_dossier' do
    before { initiated_mail.object = template }
    subject { initiated_mail.object_for_dossier(dossier) }

    it_behaves_like "can replace tokens in template"
  end

  describe '.body_for_dossier' do
    before { initiated_mail.body = template }
    subject { initiated_mail.body_for_dossier(dossier) }

    it_behaves_like "can replace tokens in template"
  end

  describe '.replace_tags' do
    it "avoids side effects" do
      subject = "n --numero_dossier--"
      expect(initiated_mail.replace_tags(subject, dossier)).to eq("n #{dossier.id}")
      expect(initiated_mail.replace_tags(subject, dossier2)).to eq("n #{dossier2.id}")
    end
  end
end
