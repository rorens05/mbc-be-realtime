ActiveAdmin.register Roulette do
  menu parent: ["Games"], priority: 1

  permit_params :radio_station_id, :location_restriction, :location_restriction_type, :text_description, :dj_id, 
                :sponsor_id, :name, :number_of_winner, :price, :schedule, :redemption_details, :dti_permit, :winner_prompt, 
                :popper_visible, :banderitas_visible, :background, :winner_background, :status, city_ids: [],
                pies_attributes: [
                    :id,
                    :icon,
                    :name,
                    :color
                  ]

  member_action :allow_player_to_join, method: [:post]  do 
    resource.start_time = DateTime.now + 100.minutes
    resource.status = "ready"
    resource.save
    redirect_to admin_roulette_path(resource), notice: "Game is ready"
  end

  member_action :start_spin, method: [:post] do 
    resource.start_time = DateTime.now
    resource.save

    Rails.logger.debug "Setting countdown"
    time = GameRecord.lobby_time
    Rails.logger.debug time.to_s
    redirect_to admin_roulette_path(resource), notice: "Game is in progress"
    
    Thread.new do
      sleep time
      Rails.logger.debug "Countdown finished"

      # check all joined users
      Rails.logger.debug "Getting all users"
      players = resource.roulette_participants.spinner

      # generate winner 
      # get number of players
      player_count = players.count
      number_of_winners = resource.number_of_winner
      number_of_winners = player_count if player_count < resource.number_of_winner

      Rails.logger.debug "Player count: " + player_count.to_s
      Rails.logger.debug "Number of winners: " + number_of_winners.to_s

      Rails.logger.debug "Generating random indexes"
      indexes = []
      while indexes.count < number_of_winners
        random_index = Faker::Number.between(from: 0, to: player_count - 1)
        indexes.push(random_index) if !indexes.include? random_index
        Rails.logger.debug "generated index: " + random_index.to_s
      end

      Rails.logger.debug "Generating Winners"

      winners = indexes.map do |item|
        players[item].winner = true
        players[item].save
      end
      Rails.logger.debug "Generating Winners"
      # broadcast winner
      # Rails.logger.debug "broadcasting"
      GameChannel.broadcast_to(
        game_params[:game_id],
        { winners: winners, player_count: player_count, players: players}
      )
      resource.status = "done"
      resource.save

    end
  end


  controller do
    def new
      super do 
          resource.pies << Pie.new(name: "Winner", color: "#%06x" % (rand * 0xffffff))
          11.times do 
          resource.pies << Pie.new(name: "Bokya", color: "#%06x" % (rand * 0xffffff))
        end
      end
    end
  end
  
  form do |f|
    tabs do 
      tab "Game Info" do 
        f.input :radio_station
        f.input :location_restriction
        div class: f.object.location_restriction ? "" : "hide", id: "roullete_location_restriction" do 
          h4 "Location Restrictions"
          f.input :cities, :as => :select, :input_html => {:multiple => true}
          f.input :location_restriction_type
          f.input :text_description, input_html: {rows: 2}
        end
        f.input :dj, collection: AdminUser.djs
        f.input :sponsor
        f.input :name, label: "Title"
        f.input :number_of_winner
        f.input :price
        f.input :background, as: :file
        f.input :winner_background, as: :file
        
        f.input :schedule, :as => :datetime_picker
        f.input :redemption_details, input_html: {rows: 2}
        f.input :dti_permit
        f.input :winner_prompt
        f.input :popper_visible
        f.input :banderitas_visible
        f.input :status

      end

      tab "Pies" do
        f.has_many :pies,
          new_record: 'Add Pie',
          remove_record: 'Remove Pie',
          allow_destroy: ->(_u) { current_admin_user.present? }, 
          class: "pie-input-container" do |b|
            b.input :icon, as: :file
            b.input :name
            b.input :color

        end
      end
    end
    f.actions
  end

  show do 
    panel roulette.name do
    
      tabs do 
        tab "Lobby" do
          render 'lobby', roulette: roulette
        end
        tab "Details" do
          columns do
            column span: 4 do
              attributes_table_for roulette do
                row :id
    
                row :radio_station_id
                row :location_restriction
                row :location_restriction_type
                row :text_description
                row :dj_id
                row :sponsor_id
                row :name
                row :number_of_winner
                row :price
                row :schedule
                row :redemption_details
                row :dti_permit
                row :winner_prompt
                row :popper_visible
                row :banderitas_visible
                row :background
                row :winner_background
                row :cities
                row :start_time
    
                row :status do
                  status_tag roulette.status.present? ? roulette.status : 'Inactive'
                end
              end
            end

            column do
              para "Background"
              if roulette.background.attached?
                img src: url_for(roulette.background), style: 'width: 100%'
              else
                "No background image"
              end

              para "Winner Background"
              if roulette.winner_background.attached?
                img src: url_for(roulette.winner_background), style: 'width: 100%'
              else
                "No winner background image"
              end
            end

          end

        end
        tab "Pies" do
          div class: 'pie-container' do
            roulette.pies.each_with_index do |pie, index|
              div class: "pie", style: "background-color: #{pie.color || 'white'}" do 
                if pie.icon.attached? 
                  img src: url_for(pie.icon)
                else
                  img src: '/images/no-image.png'
                end
                para pie.name
              end 
            end
          end
        end
      end
    end
  end
end