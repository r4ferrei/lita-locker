module Lita
  module Handlers
    class Locker < Handler
      http.get '/locker/label/:name', :http_label_show
      http.get '/locker/resource/:name', :http_resource_show

      LABEL_REGEX    = /([\W\S_-]+)/
      RESOURCE_REGEX = /([\.a-zA-Z0-9_-]+)/

      route(
        /^\(lock\)\s#{LABEL_REGEX}$/,
        :lock
      )

      route(
        /^\(unlock\)\s#{LABEL_REGEX}$/,
        :unlock
      )

      route(
        /^lock\s#{LABEL_REGEX}$/,
        :lock,
        command: true,
        help: {
          t('help.lock_key') => t('help.lock_value')
        }
      )

      # route(
      #   /^lock\s([a-zA-Z0-9_-]+)\s(\d+)(s|m|h)$/,
      #   :lock,
      #   command: true,
      #   help: {
      #     t('help.lock_time_key') => t('help.lock_time_value')
      #   }
      # )

      route(
        /^unlock\s#{LABEL_REGEX}$/,
        :unlock,
        command: true,
        help: {
          t('help.unlock_key') => t('help.unlock_value')
        }
      )

      route(
        /^unlock\s#{LABEL_REGEX}\sforce$/,
        :unlock_force,
        command: true,
        help: {
          t('help.unlock_force_key') => t('help.unlock_force_value')
        }
      )

      route(
        /^locker\sresource\slist$/,
        :resource_list,
        command: true,
        help: {
          t('help.resource_list_key') =>
          t('help.resource_list_value')
        }
      )

      route(
        /^locker\sresource\screate\s#{RESOURCE_REGEX}$/,
        :resource_create,
        command: true,
        restrict_to: [:locker_admins],
        help: {
          t('help.resource_create_key') =>
          t('help.resource_create_value')
        }
      )

      route(
        /^locker\sresource\sdelete\s#{RESOURCE_REGEX}$/,
        :resource_delete,
        command: true,
        restrict_to: [:locker_admins],
        help: {
          t('help.resource_delete_key') =>
          t('help.resource_delete_value')
        }
      )

      route(
        /^locker\sresource\sshow\s#{RESOURCE_REGEX}$/,
        :resource_show,
        command: true,
        help: {
          t('help.resource_show_key') =>
          t('help.resource_show_value')
        }
      )

      route(
        /^locker\slabel\slist$/,
        :label_list,
        command: true,
        help: {
          t('help.label_list_key') =>
          t('help.label_list_value')
        }
      )

      route(
        /^locker\slabel\screate\s#{LABEL_REGEX}$/,
        :label_create,
        command: true,
        help: {
          t('help.label_create_key') =>
          t('help.label_create_value')
        }
      )

      route(
        /^locker\slabel\sdelete\s#{LABEL_REGEX}$/,
        :label_delete,
        command: true,
        help: {
          t('help.label_delete_key') =>
          t('help.label_delete_value')
        }
      )

      route(
        /^locker\slabel\sshow\s#{LABEL_REGEX}$/,
        :label_show,
        command: true,
        help: {
          t('help.label_show_key') =>
          t('help.label_show_value')
        }
      )

      route(
        /^locker\slabel\sadd\s#{RESOURCE_REGEX}\sto\s#{LABEL_REGEX}$/,
        :label_add,
        command: true,
        help: {
          t('help.label_add_key') =>
          t('help.label_add_value')
        }
      )

      route(
        /^locker\slabel\sremove\s#{RESOURCE_REGEX}\sfrom\s#{LABEL_REGEX}$/,
        :label_remove,
        command: true,
        help: {
          t('help.label_remove_key') =>
          t('help.label_remove_value')
        }
      )

      def http_label_show(request, response)
        name = request.env['router.params'][:name]
        response.headers['Content-Type'] = 'application/json'
        result = label(name)
        response.write(result.to_json)
      end

      def http_resource_show(request, response)
        name = request.env['router.params'][:name]
        response.headers['Content-Type'] = 'application/json'
        result = resource(name)
        response.write(result.to_json)
      end

      def lock(response)
        name = response.matches[0][0]
        timeamt = response.matches[0][1]
        timeunit = response.matches[0][2]
        case timeunit
        when 's'
          time_until = Time.now.utc + timeamt.to_i
        when 'm'
          time_until = Time.now.utc + (timeamt.to_i * 60)
        when 'h'
          time_until = Time.now.utc + (timeamt.to_i * 3600)
        else
          time_until = nil
        end

        if resource_exists?(name)
          if lock_resource!(name, response.user, time_until)
            response.reply(t('resource.lock', name: name))
          else
            response.reply(t('resource.is_locked', name: name))
          end
        elsif label_exists?(name)
          m = label_membership(name)
          if m.count > 0
            if lock_label!(name, response.user, time_until)
              response.reply(t('label.lock', name: name))
            else
              l = label(name)
              if l['state'] == 'locked'
                response.reply(t('label.owned', name: name,
                                                owner: l['owner']))
              else
                response.reply(t('label.dependency'))
              end
            end
          else
            response.reply(t('label.no_resources', name: name))
          end
        else
          response.reply(t('subject.does_not_exist', name: name))
        end
      end

      def unlock(response)
        name = response.matches[0][0]
        if resource_exists?(name)
          res = resource(name)
          if res['state'] == 'unlocked'
            response.reply(t('resource.is_unlocked', name: name))
          else
            # FIXME: NOT SECURE
            if response.user.name == res['owner']
              unlock_resource!(name)
              response.reply(t('resource.unlock', name: name))
              # FIXME: Handle the case where things can't be unlocked?
            else
              response.reply(t('resource.owned', name: name,
                                                 owner: res['owner']))
            end
          end
        elsif label_exists?(name)
          l = label(name)
          if l['state'] == 'unlocked'
            response.reply(t('label.is_unlocked', name: name))
          else
            # FIXME: NOT SECURE
            if response.user.name == l['owner']
              unlock_label!(name)
              response.reply(t('label.unlock', name: name))
              # FIXME: Handle the case where things can't be unlocked?
            else
              response.reply(t('label.owned', name: name,
                                              owner: l['owner']))
            end
          end
        else
          response.reply(t('subject.does_not_exist', name: name))
        end
      end

      def unlock_force(response)
        name = response.matches[0][0]
        if resource_exists?(name)
          unlock_resource!(name)
          response.reply(t('resource.unlock', name: name))
          # FIXME: Handle the case where things can't be unlocked?
        elsif label_exists?(name)
          unlock_label!(name)
          response.reply(t('label.unlock', name: name))
          # FIXME: Handle the case where things can't be unlocked?
        else
          response.reply(t('subject.does_not_exist', name: name))
        end
      end

      def label_list(response)
        labels.each do |l|
          response.reply(t('label.desc', name: l.sub('label_', '')))
        end
      end

      def label_create(response)
        name = response.matches[0][0]
        if create_label(name)
          response.reply(t('label.created', name: name))
        else
          response.reply(t('label.exists', name: name))
        end
      end

      def label_delete(response)
        name = response.matches[0][0]
        if delete_label(name)
          response.reply(t('label.deleted', name: name))
        else
          response.reply(t('label.does_not_exist', name: name))
        end
      end

      def label_show(response)
        name = response.matches[0][0]
        if label_exists?(name)
          members = label_membership(name)
          if members.count > 0
            response.reply(t('label.resources', name: name,
                                                resources: members.join(', ')))
          else
            response.reply(t('label.has_no_resources', name: name))
          end
        else
          response.reply(t('label.does_not_exist', name: name))
        end
      end

      def label_add(response)
        resource_name = response.matches[0][0]
        label_name = response.matches[0][1]
        if label_exists?(label_name)
          if resource_exists?(resource_name)
            add_resource_to_label(label_name, resource_name)
            response.reply(t('label.resource_added', label: label_name,
                                                     resource: resource_name))
          else
            response.reply(t('resource.does_not_exist', name: resource_name))
          end
        else
          response.reply(t('label.does_not_exist', name: label_name))
        end
      end

      def label_remove(response)
        resource_name = response.matches[0][0]
        label_name = response.matches[0][1]
        if label_exists?(label_name)
          if resource_exists?(resource_name)
            members = label_membership(label_name)
            if members.include?(resource_name)
              remove_resource_from_label(label_name, resource_name)
              response.reply(t('label.resource_removed',
                               label: label_name, resource: resource_name))
            else
              response.reply(t('label.does_not_have_resource',
                               label: label_name, resource: resource_name))
            end
          else
            response.reply(t('resource.does_not_exist', name: resource_name))
          end
        else
          response.reply(t('label.does_not_exist', name: label_name))
        end
      end

      def resource_list(response)
        resources.each do |r|
          r_name = r.sub('resource_', '')
          res = resource(r_name)
          response.reply(t('resource.desc', name: r_name, state: res['state']))
        end
      end

      def resource_create(response)
        name = response.matches[0][0]
        if create_resource(name)
          response.reply(t('resource.created', name: name))
        else
          response.reply(t('resource.exists', name: name))
        end
      end

      def resource_delete(response)
        name = response.matches[0][0]
        if delete_resource(name)
          response.reply(t('resource.deleted', name: name))
        else
          response.reply(t('resource.does_not_exist', name: name))
        end
      end

      def resource_show(response)
        name = response.matches[0][0]
        if resource_exists?(name)
          r = resource(name)
          response.reply(t('resource.desc', name: name, state: r['state']))
        else
          response.reply(t('resource.does_not_exist', name: name))
        end
      end

      private

      def create_label(name)
        label_key = "label_#{name}"
        redis.hset(label_key, 'state', 'unlocked') unless
          resource_exists?(name) || label_exists?(name)
      end

      def delete_label(name)
        label_key = "label_#{name}"
        redis.del(label_key) if label_exists?(name)
      end

      def label_exists?(name)
        redis.exists("label_#{name}")
      end

      def label_membership(name)
        redis.smembers("membership_#{name}")
      end

      def add_resource_to_label(label, resource)
        if label_exists?(label) && resource_exists?(resource)
          redis.sadd("membership_#{label}", resource)
        end
      end

      def remove_resource_from_label(label, resource)
        if label_exists?(label) && resource_exists?(resource)
          redis.srem("membership_#{label}", resource)
        end
      end

      def create_resource(name)
        resource_key = "resource_#{name}"
        redis.hset(resource_key, 'state', 'unlocked') unless
          resource_exists?(name) || label_exists?(name)
      end

      def delete_resource(name)
        resource_key = "resource_#{name}"
        redis.del(resource_key) if resource_exists?(name)
      end

      def resource_exists?(name)
        redis.exists("resource_#{name}")
      end

      def lock_resource!(name, owner, time_until)
        if resource_exists?(name)
          resource_key = "resource_#{name}"
          value = redis.hget(resource_key, 'state')
          if value == 'unlocked'
            # FIXME: Race condition!
            # FIXME: Store something better than name
            redis.hset(resource_key, 'state', 'locked')
            redis.hset(resource_key, 'owner', owner.name)
            redis.hset(resource_key, 'until', time_until)
            true
          else
            false
          end
        else
          false
        end
      end

      def lock_label!(name, owner, time_until)
        if label_exists?(name)
          key = "label_#{name}"
          members = label_membership(name)
          members.each do |m|
            r = resource(m)
            return false if r['state'] == 'locked'
          end
          # FIXME: No, really, race condition.
          members.each do |m|
            lock_resource!(m, owner, time_until)
          end
          redis.hset(key, 'state', 'locked')
          redis.hset(key, 'owner', owner.name)
          redis.hset(key, 'until', time_until)
          true
        else
          false
        end
      end

      def unlock_resource!(name)
        if resource_exists?(name)
          # FIXME: Tracking here?
          key = "resource_#{name}"
          redis.hset(key, 'state', 'unlocked')
          redis.hset(key, 'owner', '')
        else
          false
        end
      end

      def unlock_label!(name)
        if label_exists?(name)
          key = "label_#{name}"
          members = label_membership(name)
          members.each do |m|
            unlock_resource!(m)
          end
          redis.hset(key, 'state', 'unlocked')
          redis.hset(key, 'owner', '')
          true
        else
          false
        end
      end

      def resource(name)
        redis.hgetall("resource_#{name}")
      end

      def resources
        redis.keys('resource_*')
      end

      def label(name)
        redis.hgetall("label_#{name}")
      end

      def labels
        redis.keys('label_*')
      end
    end

    Lita.register_handler(Locker)
  end
end
