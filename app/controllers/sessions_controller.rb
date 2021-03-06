class SessionsController < ApplicationController

  before_filter :authorize, only: [:destroy]

  def new
  end

  def create
    email_or_username = params[:email_or_username]
    user = User.where(
      'LOWER(email) = LOWER(?) OR LOWER(username) = LOWER(?)',
      email_or_username, email_or_username
    ).first

    if user && user.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to root_url, flash: {info: 'Logged in!'}
    else
      flash.now.alert = 'Email or password is invalid'
      render 'new'
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_url, flash: {info: "Logged out!"}
  end

end