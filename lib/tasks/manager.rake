
namespace :manager do

  desc "Import, validate, tag and point matches"
  task :all => [:import, :validate, :tags, :points] do
    Rake::Task['manager:points:total'].reenable
    Rake::Task['manager:points:total'].invoke
  end

  desc "Import matches from the servers"
  task :import => :environment do

    begin
      logger.started('IMPORT')

      server = Server.where(name: 'KGS').first
      importer = ASR::SGFImporter.new(server: server, ignore_case: true)

      accounts = server.accounts
      handles = (ENV['handle'] || ENV['handles']).to_s.split(',')
      accounts = server.accounts.where('handle IN (?)', handles) if handles.any?

      accounts.each do |account|
        logger.w "Processing #{account.handle}..."

        started_at = Time.now.to_f
        year = ENV['year'] || Time.now.year
        month = ENV['month'] || Time.now.month
        matches = importer.import_matches(handle: account.handle, year: year, month: month)

        matches.each do |match|
          match_attrs = get_match_event_related_attributes(match, ignore_case: importer.ignore_case)
          next unless match_attrs
          match.attributes = match_attrs
          match.save
        end

        time = (Time.now.to_f - started_at).to_f.round(2)
        logger.wl "#{matches.size} matches in #{time} seconds"
      end
    rescue Exception => exc
      logger.error exc
    ensure
      touch_events
      logger.ended
    end
  end

  desc "Validate unvalidated matches"
  task :validate => :environment do

    begin
      logger.started('VALIDATE')

      Event.all.each do |event|
        div_matches = Match.unvalidated.by_event(event).group_by(&:division_id)
        div_matches.each do |div_id, matches|
          div = Division.where(id: div_id).includes(:ruleset).first
          validator = ASR::MatchValidator.new(div.rules)
          matches.each do |match|
            logger.w "Validating #{match.digest}..."

            is_valid = validator.valid?(match)
            match.update_attributes(
              valid_match: is_valid,
              validation_errors: validator.errors.join(','))

            logger.wl is_valid.to_s.upcase
          end
        end
      end
    rescue Exception => exc
      logger.exception exc
    ensure
      touch_events
      logger.ended
    end
  end

  namespace :validate do
    desc 'Recheck the validation of all matches'
    task :redo => :environment do

      Match.update_all(valid_match: nil, validation_errors: nil)
      Rake::Task['manager:validate'].reenable
      Rake::Task['manager:validate'].invoke
    end
  end


  desc "Check tags for unchecked matches"
  task :tags => :environment do

    begin
      logger.started('TAGS')

      Event.all.each do |event|
        tag_checker = ASR::TagChecker.new(event.tags)
        Match.unchecked.by_event(event).each do |match|
          logger.w "Checking...#{match.digest}"

          node_limit = match.division.rules[:node_limit]
          is_tagged = tag_checker.tagged?(match.tags, node_limit)
          match.update_attribute(:tagged, is_tagged)

          logger.wl is_tagged.to_s.upcase
        end
      end
    rescue Exception => exc
      logger.exception exc
    ensure
      touch_events
      logger.ended
    end
  end

  namespace :tags do
    desc 'Recheck the tags of all matches'
    task :redo => :environment do

      Match.update_all(tagged: nil)
      Rake::Task['manager:tags'].reenable
      Rake::Task['manager:tags'].invoke
    end
  end

  desc "Calculate points for all events"
  task :points => :environment do

    begin
      logger.started 'POINTS'

      Event.all.each do |event|
        logger.wl "EVENT #{event.name}..."

        finder = ASR::MatchFinder.new(
          event: event,
          from: event.starts_at,
          to: event.ends_at)

        point_manager = ASR::PointManager.new(finder: finder)
        event.registrations.each do |reg|
          logger.w "Calculating #{reg.handle}..."

          matches = finder.by_registration(reg).tagged.valid.without_points
          points = point_manager.points_for(matches)
          points.each(&:save)
          points.collect(&:match).each { |m| m.update_attribute(:has_points, true)}

          logger.wl "#{points.size.to_f} points"
        end
      end
    rescue Exception => exc
      logger.exception exc
    ensure
      touch_events
      logger.ended
    end
  end



  namespace :points do
    desc 'Recount the points of all matches'
    task :redo => :environment do

      # TODO: This is dangerous, it should destroy only the point
      # from the matches that is recalculating
      Match.update_all(has_points: false)
      Point.destroy_all
      Rake::Task['manager:points'].reenable
      Rake::Task['manager:points'].invoke
    end

    desc "Total registration points"
    task :total => :environment do

      begin
        logger.started 'TOTALLING POINTS'

        Event.all.each do |event|
          logger.wl "EVENT #{event.name}..."

          event.registrations.each do |reg|
            logger.w "Totalling #{reg.handle}..."

            total = reg.points.collect(&:count).inject(&:+) || 0
            reg.update_attribute(:points_this_month, total)

            logger.wl "#{total} points"
          end
        end
      rescue Exception => exc
        logger.exception exc
      ensure
        touch_events
        logger.ended
      end
    end

  end

  task :ranks => :environment do
    desc 'Get ranks from comments for all registrations'

    begin
      logger.started 'RANKS'

      Registration.all.each do |reg|
        logger.wl "REGISTRATION #{reg.handle}..."
        rank = Utilities::rank_convert(reg.get_rank)
        reg.account.update_attribute(:rank, rank)
        logger.wl "Rank: #{Utilities::format_rank(rank)}"
      end
    rescue Exception => exc
      logger.exception exc
    ensure
      touch_events
      logger.ended
    end
  end

  task :rollover => :environment do
    desc 'Rollover one league into a new month'

    event = Event.find_by_name('ASR League July')
    new_event = Event.create(event.attributes.merge(id: nil, name: "ASR League September", starts_at: "2013-09-01", ends_at: "2013-09-30"), without_protection: true)
    new_event.create_ruleset(event.ruleset.attributes.merge(id: nil, rulesetable_id: nil, rulesetable_type: nil), without_protection: true)
    new_event.create_point_ruleset(event.point_ruleset.attributes.merge(id: nil, pointable_id: nil, pointable_type: nil), without_protection: true)

    event_tags = event.tags
    event_tags.each do |et|
      et.update_attribute(:event_id, new_event.id)
    end

    event.tiers.each do |tier|
      new_tier = new_event.tiers.create(tier.attributes.merge(id: nil, event_id: nil), without_protection: true)
      new_tier.create_ruleset(tier.ruleset.attributes.merge(id: nil, rulesetable_id: nil, rulesetable_type: nil), without_protection: true)

      tier.divisions.each do |div|
        new_division = new_tier.divisions.create(div.attributes.merge(id: nil, tier_id: nil), without_protection: true)
        new_division.create_ruleset(div.ruleset.attributes.merge(id: nil, rulesetable_id: nil, rulesetable_type: nil), without_protection: true)
        div.registrations.each do |reg|
          new_division.registrations.create(reg.attributes.merge(
            id: nil,
            event_id: new_event.id,
            division_id: nil,
            points_this_month: 0), without_protection: true)
        end
      end
    end

    # Copy unnassigned registrations
    event.registrations.where(division_id: nil).each do |reg|
      event.registrations.create(reg.attributes.merge(
        id: nil,
        points_this_month: 0), without_protection: true)
    end

  end

  private

    def logger
      @logger ||= TaskLogger.new("#{Rails.root}/log/manager.log")
    end

    # Sledge hammer cache breaker. Refine it in the future
    # once the rake tasks are per event
    def touch_events
      ActiveRecord::Base.connection.execute("UPDATE events SET updated_at = NOW()")
    end

    def get_match_event_related_attributes(match, options={})
      opts = { ignore_case: false }.merge(options)
      wp_name = match.white_player_name
      bp_name = match.black_player_name

      event = ASR::EventFinder.find(
        tags: match.tags.collect(&:phrase),
        handles: [bp_name, wp_name],
        date: match.completed_at)
      return nil unless event

      if opts[:ignore_case]
        wp_name = wp_name.downcase
        bp_name = bp_name.downcase
        query = 'event_id = ? AND LOWER(accounts.handle) = ?'
      else
        query = 'event_id = ? AND accounts.handle = ?'
      end

      w_reg = Registration.joins(:account).where(
        query, event.id, wp_name).first
      b_reg = Registration.joins(:account).where(
        query, event.id, bp_name).first

      {
        white_player: w_reg,
        black_player: b_reg,
        winner: match.won_by == "W" ? w_reg : b_reg,
        loser: match.won_by == "B" ? w_reg : b_reg,
        division_id: w_reg.division_id
      }
    end

end
