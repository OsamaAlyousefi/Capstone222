const slugifyCompany = (company) =>
  company.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');

export const buildApplicationReceivedMessage = ({ fullName, jobTitle, company }) => {
  return {
    sender_name: `${company} Talent Team`,
    sender_email: `talent@${slugifyCompany(company) || 'company'}.com`,
    subject: `Application received for ${jobTitle}`,
    body:
      `Hello ${fullName || 'there'},\n\n` +
      `We received your application for ${jobTitle}. ` +
      'Our team will review it shortly and you will see status updates in your SmartJob inbox.\n\n' +
      `Regards,\n${company} Talent Team`,
    category: 'update'
  };
};

export const buildSimulatedInboxMessage = ({
  fullName,
  jobTitle,
  company,
  messageType
}) => {
  switch (messageType) {
    case 'interview':
      return {
        message: {
          sender_name: `${company} Recruiting`,
          sender_email: `recruiting@${slugifyCompany(company) || 'company'}.com`,
          subject: `Interview Invitation — ${jobTitle} at ${company}`,
          body:
            `Dear ${fullName || 'candidate'},\n\n` +
            'We were impressed with your application and would like to invite you for an interview. ' +
            'Please reply with your availability for next week.\n\n' +
            `Best,\n${company} Recruiting`,
          category: 'interview'
        },
        applicationStatus: 'interview'
      };
    case 'rejection':
      return {
        message: {
          sender_name: `${company} Talent Team`,
          sender_email: `talent@${slugifyCompany(company) || 'company'}.com`,
          subject: `Update on your application for ${jobTitle}`,
          body:
            `Dear ${fullName || 'candidate'},\n\n` +
            `Thank you for your interest in ${company}. After careful consideration, ` +
            'we have decided to move forward with other candidates. We encourage you to apply again in future.\n\n' +
            `Regards,\n${company} Talent Team`,
          category: 'rejection'
        },
        applicationStatus: 'rejected'
      };
    case 'offer':
      return {
        message: {
          sender_name: `${company} People Team`,
          sender_email: `people@${slugifyCompany(company) || 'company'}.com`,
          subject: `Job Offer — ${jobTitle} at ${company}`,
          body:
            `Dear ${fullName || 'candidate'},\n\n` +
            `We are delighted to offer you the position of ${jobTitle} at ${company}. ` +
            'Please review the offer details and let us know if you have any questions.\n\n' +
            `Warm regards,\n${company} People Team`,
          category: 'offer'
        },
        applicationStatus: 'accepted'
      };
    default:
      return {
        message: {
          sender_name: `${company} Talent Team`,
          sender_email: `talent@${slugifyCompany(company) || 'company'}.com`,
          subject: `Following up on your application for ${jobTitle}`,
          body:
            `Hello ${fullName || 'candidate'},\n\n` +
            'We wanted to follow up to let you know your application is still under review. ' +
            'We appreciate your patience.\n\n' +
            `Regards,\n${company} Talent Team`,
          category: 'update'
        },
        applicationStatus: null
      };
  }
};
