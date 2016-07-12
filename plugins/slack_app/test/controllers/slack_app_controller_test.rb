require_relative '../test_helper'

SingleCov.covered!

describe SlackAppController do
  as_a_viewer do
    describe 'oauth' do
    end
  end

  describe 'incoming commands' do
    it "raises if secret token doesn't match" do
      assert_raises RuntimeError do
        post :command, token: 'thiswontmatch'
      end
    end

    describe 'without Slack linkage' do
      it "returns a private error if the user isn't matched up" do
        post :command, user_id: 'notconnected'
        assert "don't recognize you".in? @response.body
      end
    end

    describe 'with Slack linkage' do
      beforeEach do
        # TODO: mock up a SlackIdentifier for one or more users
      end
    end
  end
end
