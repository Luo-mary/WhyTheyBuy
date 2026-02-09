"""
Email service for sending notifications.

COMPLIANCE: All emails must include legal disclaimers.
"""
import logging
from typing import Optional
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail, Email, To, Content

from app.config import settings
from app.services.auth import create_email_verification_token

logger = logging.getLogger(__name__)

# Initialize SendGrid client
if settings.sendgrid_api_key:
    sg_client = SendGridAPIClient(api_key=settings.sendgrid_api_key)
else:
    sg_client = None


# =============================================================================
# LEGAL DISCLAIMER FOOTER (REQUIRED IN ALL EMAILS)
# =============================================================================

LEGAL_DISCLAIMER_HTML = """
<div style="margin-top: 32px; padding-top: 24px; border-top: 1px solid #e5e7eb;">
    <div style="background: #fef3c7; border-left: 4px solid #f59e0b; padding: 16px; margin-bottom: 16px; font-size: 13px; color: #92400e;">
        <strong>⚠️ Important Disclaimer</strong><br><br>
        This email and its contents are for <strong>informational purposes only</strong> and do not constitute:
        <ul style="margin: 8px 0; padding-left: 20px;">
            <li>Investment advice or recommendations</li>
            <li>An offer or solicitation to buy or sell securities</li>
            <li>Tax, legal, or financial advice</li>
        </ul>
        The information presented describes publicly disclosed holdings changes by institutional investors. 
        We do not know the actual reasoning behind their decisions. All interpretations are hypothetical.
        <br><br>
        <strong>Past holdings changes do not indicate future actions.</strong> 
        Please consult a qualified financial advisor before making any investment decisions.
    </div>
    <p style="font-size: 11px; color: #6b7280; text-align: center; margin: 0;">
        © {year} WhyTheyBuy. All rights reserved.<br>
        WhyTheyBuy is a financial information service, not a registered investment advisor.
    </p>
</div>
"""

LEGAL_DISCLAIMER_TEXT = """
---
IMPORTANT DISCLAIMER

This email is for INFORMATIONAL PURPOSES ONLY and does not constitute:
- Investment advice or recommendations
- An offer or solicitation to buy or sell securities
- Tax, legal, or financial advice

The information describes publicly disclosed holdings changes. We do not know 
the actual reasoning behind investor decisions. All interpretations are hypothetical.

Past holdings changes do not indicate future actions. Please consult a qualified 
financial advisor before making any investment decisions.

© {year} WhyTheyBuy. All rights reserved.
WhyTheyBuy is a financial information service, not a registered investment advisor.
"""


def _get_disclaimer_html() -> str:
    """Get HTML disclaimer with current year."""
    from datetime import datetime
    return LEGAL_DISCLAIMER_HTML.format(year=datetime.now().year)


def _get_disclaimer_text() -> str:
    """Get text disclaimer with current year."""
    from datetime import datetime
    return LEGAL_DISCLAIMER_TEXT.format(year=datetime.now().year)


# =============================================================================
# EMAIL SENDING FUNCTIONS
# =============================================================================

async def send_email(
    to_email: str,
    subject: str,
    html_content: str,
    text_content: Optional[str] = None,
    include_disclaimer: bool = True,
) -> bool:
    """Send an email via SendGrid."""
    if not sg_client:
        logger.warning(f"SendGrid not configured. Would send email to {to_email}: {subject}")
        return False
    
    # Append disclaimer to content if required
    if include_disclaimer:
        html_content = html_content + _get_disclaimer_html()
        if text_content:
            text_content = text_content + _get_disclaimer_text()
    
    try:
        logger.info(f"Attempting to send email from {settings.from_email} to {to_email}")
        message = Mail(
            from_email=Email(settings.from_email, "WhyTheyBuy"),
            to_emails=To(to_email),
            subject=subject,
            html_content=html_content,
        )

        if text_content:
            message.add_content(Content("text/plain", text_content))

        response = sg_client.send(message)

        if response.status_code in [200, 201, 202]:
            logger.info(f"Email sent successfully to {to_email}")
            return True
        else:
            logger.error(f"Failed to send email: status={response.status_code}, body={response.body}, headers={response.headers}")
            return False

    except Exception as e:
        logger.error(f"Error sending email: {e}")
        # Log more details for common SendGrid errors
        error_str = str(e)
        if "403" in error_str:
            logger.error(f"SendGrid 403 Forbidden - from_email={settings.from_email}")
            logger.error("Check: 1) API key has 'Mail Send' permission, 2) Sender identity is verified, 3) Account is not restricted")
        elif "401" in error_str:
            logger.error("SendGrid 401 Unauthorized - Invalid API key")
        # Try to get more details from the exception
        if hasattr(e, 'body'):
            logger.error(f"SendGrid error body: {e.body}")
        return False


async def send_verification_email(email: str, user_id: str) -> bool:
    """Send email verification link."""
    token = create_email_verification_token(user_id)
    verification_url = f"{settings.app_url}/verify-email?token={token}"
    
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; }}
            .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
            .header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }}
            .content {{ background: #f9fafb; padding: 30px; border-radius: 0 0 8px 8px; }}
            .button {{ display: inline-block; background: #667eea; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; margin: 20px 0; }}
            .footer {{ text-align: center; color: #6b7280; font-size: 12px; margin-top: 20px; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>Welcome to WhyTheyBuy</h1>
            </div>
            <div class="content">
                <p>Thanks for signing up! Please verify your email address to get started.</p>
                <p style="text-align: center;">
                    <a href="{verification_url}" class="button">Verify Email</a>
                </p>
                <p>Or copy and paste this link:</p>
                <p style="word-break: break-all; color: #667eea;">{verification_url}</p>
                <p>This link will expire in 24 hours.</p>
            </div>
            <div class="footer">
                <p>WhyTheyBuy - Financial Information & Analytics</p>
                <p>If you didn't create an account, you can safely ignore this email.</p>
            </div>
        </div>
    </body>
    </html>
    """
    
    return await send_email(
        to_email=email,
        subject="Verify your WhyTheyBuy email",
        html_content=html_content,
        include_disclaimer=False,  # Verification emails don't need full disclaimer
    )


async def send_password_reset_email(email: str, token: str) -> bool:
    """Send password reset link."""
    reset_url = f"{settings.app_url}/reset-password?token={token}"
    
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; }}
            .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
            .header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }}
            .content {{ background: #f9fafb; padding: 30px; border-radius: 0 0 8px 8px; }}
            .button {{ display: inline-block; background: #667eea; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; margin: 20px 0; }}
            .footer {{ text-align: center; color: #6b7280; font-size: 12px; margin-top: 20px; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>Password Reset</h1>
            </div>
            <div class="content">
                <p>You requested to reset your password. Click the button below to set a new password:</p>
                <p style="text-align: center;">
                    <a href="{reset_url}" class="button">Reset Password</a>
                </p>
                <p>Or copy and paste this link:</p>
                <p style="word-break: break-all; color: #667eea;">{reset_url}</p>
                <p>This link will expire in 1 hour.</p>
            </div>
            <div class="footer">
                <p>WhyTheyBuy - Financial Information & Analytics</p>
                <p>If you didn't request this reset, you can safely ignore this email.</p>
            </div>
        </div>
    </body>
    </html>
    """
    
    return await send_email(
        to_email=email,
        subject="Reset your WhyTheyBuy password",
        html_content=html_content,
        include_disclaimer=False,  # Password reset doesn't need full disclaimer
    )


async def send_holdings_change_alert(
    to_email: str,
    investor_name: str,
    summary: dict,
    report_url: str,
) -> bool:
    """
    Send holdings change alert email.
    
    COMPLIANCE: This email describes publicly disclosed holdings changes.
    Disclaimer is automatically appended.
    """
    
    # Build top buys HTML
    top_buys_html = ""
    for buy in summary.get("top_buys", [])[:3]:
        ticker = buy.get('ticker', '')
        name = buy.get('name', '')
        change = buy.get('change', '')
        company_url = f"{settings.app_url}/companies/{ticker}"
        top_buys_html += f"""
        <tr>
            <td style="padding: 12px; border-bottom: 1px solid #e5e7eb;">
                <a href="{company_url}" style="color: #667eea; text-decoration: none;">
                    <strong>{ticker}</strong>
                </a> - {name}
            </td>
            <td style="padding: 12px; border-bottom: 1px solid #e5e7eb; color: #10b981;">
                {change}
            </td>
        </tr>
        """
    
    # Build top sells HTML
    top_sells_html = ""
    for sell in summary.get("top_sells", [])[:3]:
        ticker = sell.get('ticker', '')
        name = sell.get('name', '')
        change = sell.get('change', '')
        company_url = f"{settings.app_url}/companies/{ticker}"
        top_sells_html += f"""
        <tr>
            <td style="padding: 12px; border-bottom: 1px solid #e5e7eb;">
                <a href="{company_url}" style="color: #667eea; text-decoration: none;">
                    <strong>{ticker}</strong>
                </a> - {name}
            </td>
            <td style="padding: 12px; border-bottom: 1px solid #e5e7eb; color: #ef4444;">
                {change}
            </td>
        </tr>
        """
    
    # Build observations HTML
    observations = summary.get("observations", [])
    observations_html = ""
    if observations:
        observations_html = "<ul style='margin: 0; padding-left: 20px;'>"
        for obs in observations[:3]:
            observations_html += f"<li style='margin-bottom: 4px;'>{obs}</li>"
        observations_html += "</ul>"
    
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; }}
            .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
            .header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }}
            .content {{ background: #f9fafb; padding: 30px; border-radius: 0 0 8px 8px; }}
            .section {{ background: white; border-radius: 8px; padding: 20px; margin: 15px 0; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }}
            .button {{ display: inline-block; background: #667eea; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; margin: 20px 0; }}
            table {{ width: 100%; border-collapse: collapse; }}
            .footer {{ text-align: center; color: #6b7280; font-size: 12px; margin-top: 20px; padding: 20px; }}
            .inline-disclaimer {{ background: #fef3c7; border-left: 4px solid #f59e0b; padding: 12px; margin: 15px 0; font-size: 13px; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>📊 Holdings Update</h1>
                <p>{investor_name}</p>
            </div>
            <div class="content">
                <h2>{summary.get('headline', 'New Holdings Changes Disclosed')}</h2>
                
                {f'''
                <div class="section">
                    <h4 style="margin-top: 0; color: #374151;">📋 Observations</h4>
                    {observations_html}
                </div>
                ''' if observations_html else ''}
                
                {f'''
                <div class="section">
                    <h3 style="color: #10b981; margin-top: 0;">🟢 Top Buys (Disclosed)</h3>
                    <table>{top_buys_html}</table>
                </div>
                ''' if top_buys_html else ''}
                
                {f'''
                <div class="section">
                    <h3 style="color: #ef4444; margin-top: 0;">🔴 Top Sells (Disclosed)</h3>
                    <table>{top_sells_html}</table>
                </div>
                ''' if top_sells_html else ''}
                
                <div class="inline-disclaimer">
                    <strong>ℹ️ Note:</strong> This describes publicly disclosed holdings changes. 
                    We do not know the investor's actual reasoning. Market price ranges shown are 
                    for reference only and may not reflect actual execution prices.
                </div>
                
                <p style="text-align: center;">
                    <a href="{report_url}" class="button">View Full Report</a>
                </p>
            </div>
            <div class="footer">
                <p>WhyTheyBuy - Financial Information & Analytics</p>
                <p><a href="{settings.app_url}/settings">Manage notification preferences</a></p>
            </div>
        </div>
    </body>
    </html>
    """
    
    return await send_email(
        to_email=to_email,
        subject=f"📊 {investor_name}: {summary.get('headline', 'Holdings Update')}",
        html_content=html_content,
        include_disclaimer=True,  # Always include legal disclaimer for holdings emails
    )


async def send_weekly_digest(
    to_email: str,
    digest_data: dict,
) -> bool:
    """
    Send weekly digest email.
    
    COMPLIANCE: Describes publicly disclosed changes only.
    """
    
    # Build investor summaries
    investor_summaries = ""
    for investor in digest_data.get("investors", []):
        investor_url = f"{settings.app_url}/investors/{investor.get('id', '')}"
        investor_summaries += f"""
        <div class="section">
            <h3>
                <a href="{investor_url}" style="color: #667eea; text-decoration: none;">
                    {investor['name']}
                </a>
            </h3>
            <p>{investor.get('summary', 'No disclosed changes this week')}</p>
            <p>
                <span style="color: #10b981;">+{investor.get('buys', 0)} disclosed buys</span> | 
                <span style="color: #ef4444;">-{investor.get('sells', 0)} disclosed sells</span>
            </p>
        </div>
        """
    
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; }}
            .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
            .header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }}
            .content {{ background: #f9fafb; padding: 30px; border-radius: 0 0 8px 8px; }}
            .section {{ background: white; border-radius: 8px; padding: 20px; margin: 15px 0; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }}
            .button {{ display: inline-block; background: #667eea; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; margin: 20px 0; }}
            .footer {{ text-align: center; color: #6b7280; font-size: 12px; margin-top: 20px; }}
            .inline-disclaimer {{ background: #f3f4f6; border-left: 4px solid #9ca3af; padding: 12px; margin: 15px 0; font-size: 13px; color: #6b7280; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>📰 Weekly Digest</h1>
                <p>{digest_data.get('week_label', 'This Week')}</p>
            </div>
            <div class="content">
                <p style="color: #6b7280; font-size: 14px;">
                    Summary of publicly disclosed holdings changes from your watched investors.
                </p>
                
                {investor_summaries if investor_summaries else '<p>No disclosed updates from your watched investors this week.</p>'}
                
                <div class="inline-disclaimer">
                    This digest summarizes publicly disclosed holdings changes. 
                    It does not constitute investment advice.
                </div>
                
                <p style="text-align: center;">
                    <a href="{settings.app_url}/dashboard" class="button">View Dashboard</a>
                </p>
            </div>
            <div class="footer">
                <p>WhyTheyBuy - Financial Information & Analytics</p>
                <p><a href="{settings.app_url}/settings">Manage notification preferences</a></p>
            </div>
        </div>
    </body>
    </html>
    """
    
    return await send_email(
        to_email=to_email,
        subject=f"📰 WhyTheyBuy Weekly Digest - {digest_data.get('week_label', 'This Week')}",
        html_content=html_content,
        include_disclaimer=True,  # Always include legal disclaimer
    )
