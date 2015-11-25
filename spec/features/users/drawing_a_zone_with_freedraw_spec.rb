require 'spec_helper'

feature 'drawing a zone with freedraw' do
  let(:user) { create(:user) }
  let(:dossier) { create(:dossier, :with_procedure, :with_entreprise, user: user) }

  context 'when user is not logged in' do
    before do
      visit users_dossier_carte_path dossier_id: dossier.id
    end

    scenario 'he is redirected to login page' do
      expect(page).to have_css('#login_user')
    end

    context 'when he enter login information' do
      before do
        within('#new_user') do
          page.find_by_id('user_email').set user.email
          page.find_by_id('user_password').set user.password
          page.click_on 'Se connecter'
        end
      end

      scenario 'he is redirected to carte page' do
        expect(page).to have_css('.content #map')
      end

      context 'when draw a zone on #map', js: true  do
        before do
          allow_any_instance_of(Users::CarteController).
              to receive(:generate_qp).
                     and_return({"QPCODE1234" => { :code => "QPCODE1234", :nom => "Quartier de test", :commune => "Paris", :geometry => { :type=>"MultiPolygon", :coordinates=>[[[[2.38715792094576, 48.8723062632126], [2.38724851642619, 48.8721392348061]]]] }}})

          page.execute_script('freeDraw.fire("markers", {latLngs: []});')
          wait_for_ajax
        end

        scenario 'QP name is present on page' do
          expect(page).to have_content('Quartier de test')
        end

        scenario 'Commune is present on page' do
          expect(page).to have_content('Paris')
        end
      end
    end
  end
end