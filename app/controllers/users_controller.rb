class UsersController < ApplicationController

  before_action except: [:show, :login, :index, :send_email_address_request, :set_password_and_address] do
    @user = User.enabled.where(id: params[:id]).first
    if current_user
      if current_user != @user
        redirect_to root_path, alert: "Access denied"
      end
    else
      redirect_to new_user_session_path(return_url: request.url)
    end
  end

  def show
    @user = User.find(params[:id])
    commontator_thread_show(@user)
  end

  def index
    @users = User.order(withdrawn_amount: :desc, commits_count: :desc).where('commits_count > 0').page(params[:page]).per(30)
  end

  def update
    if @user.update(users_params)
      redirect_to @user, notice: 'Your information was saved.'
    else
      render :show, alert: 'Error updating peercoin address'
    end
  end

  def login
    @user = User.where(login_token: params[:token]).first
    if @user
      if params[:unsubscribe]
        @user.update unsubscribed: true
        flash[:alert] = 'You unsubscribed! Sorry for bothering you. Although, you still can leave us your peercoin address to get your tips.'
      end
      sign_in_and_redirect @user, event: :authentication
    else
      redirect_to root_url, alert: 'User not found'
    end
  end
 
  def send_tips_back
    @user.tips.not_sent.non_refunded.each do |tip|
      tip.touch :refunded_at
    end
    redirect_to @user, notice: 'All your tips have been refunded to their project'
  end

  def send_email_address_request
    tip = Tip.find(params[:tip_id])
    authorize! :update, tip.distribution
    tip.user.reset_confirmation_token!
    UserMailer.address_request(tip, current_user).deliver
    redirect_to params[:return_url], notice: "Request sent"
  end

  def set_password_and_address
    @user = User.enabled.find(params[:id])
    raise "Blank token" if params[:token].blank?
    raise "Invalid token" unless Devise.secure_compare(params[:token], @user.confirmation_token)
    if params[:user]
      @user.attributes = params.require(:user).permit(:password, :password_confirmation, :bitcoin_address)
      if @user.password.present? and @user.bitcoin_address.present? and @user.save
        @user.confirm!
        redirect_to root_path, notice: "Information saved"
      else
        flash.now[:alert] = "Please fill all the information"
      end
    end
  end

  private
    def users_params
      params.require(:user).permit(:bitcoin_address)
    end
end
