class SlackMessageService
  def initialize(deploy)
    @deploy = deploy
  end

  def message_body
    ret = if @deploy.waiting_for_buddy?
      waiting_for_buddy_body
    elsif @deploy.running?
      running_body
    elsif @deploy.failed?
      failed_body
    end
    ret['response_type'] = 'in_channel'
    ret
  end

  def waiting_for_buddy_body
    {
      text: title_str,
      attachments: [
        {
          text: pr_str,
          callback_id: deploy.id,
          attachment_type: 'default',
          actions: [
            button(':+1: Approve', 'yes')
          ]
        }
      ]
    }
  end

  def running_body
    {
      text: title_str,
      attachments: [
        {
          text: pr_str + '\nDeploying…',
          attachment_type: 'default',
          color: 'warning'
        }
      ]
    }
  end

  def failed_body
    {
      text: ':x: ' + title_str('failed to deploy'),
    }
  end

  def succeeded_body
    {
      text: ':tada: ' + title_str('successfully deployed')
    }
  end

  def title_str(ended = nil)
    if @deploy.buddy
      owner = SlackIdentifier.find_by_user_id(@deploy.user.id)
      buddy = SlackIdentifier.find_by_user_id(@deploy.buddy.id)
      str = "<@#{owner.identifier}> and <@#{buddy.identifier}> are "
    else
      owner = SlackIdentifier.find_by_user_id(@deploy.user.id)
      str = "<@#{owner.identifier}> " + \
      if ended
        "#{ended} "
      elsif @deploy.waiting_for_buddy?
        'wants to deploy '
      else
        'is deploying '
      end
    end

    stage = @deploy.stage
    str << "<#{@deploy.url}|*#{stage.project.name}* to *#{stage.name}*>."
  end

  def pr_str
    "(list PRs here)"
  end
end
