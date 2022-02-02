from pynotifier import Notification
def notify(sender, message):
    Notification(title=f'Message from {sender}', description=message, duration=15, urgency='normal').send()
