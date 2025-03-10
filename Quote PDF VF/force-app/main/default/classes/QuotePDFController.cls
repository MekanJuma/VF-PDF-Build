public with sharing class QuotePDFController {

    public List<QuoteLineItemWrapper> quoteLineItemWrappers { get; set; }

    @TestVisible private final Quote quote;
    public String companyName {get; set;}
    public QuoteFooterInformation__mdt footerInformation {get; set;}

    public QuotePDFController(ApexPages.StandardController stdController) {
        this.quote = [SELECT Id, Name, TotalPrice, ShippingCostNet__c, Tax, GrandTotal, ShippingHandling, CurrencyIsoCode FROM Quote WHERE Id = :stdController.getId()];
        
        quoteLineItemWrappers = new List<QuoteLineItemWrapper>();
       
        for (QuoteLineItem qli : [SELECT Id, UnitPrice, TotalPrice, Product2.Name, DescriptionRichText__c, Quantity, StartDate__c, EndDate__c FROM QuoteLineItem WHERE QuoteId = :stdController.getId()]) {
            quoteLineItemWrappers.add(new QuoteLineItemWrapper(qli));
        }

        this.companyName = [SELECT Id, CompanyPicklist__c FROM User WHERE Id = :UserInfo.getUserId()].CompanyPicklist__c;
        this.footerInformation = QuoteFooterInformation__mdt.getInstance(companyName);
    }

    // Wrapper class for line items
    public class QuoteLineItemWrapper {
        public QuoteLineItem item { get; set; }
        public String formattedUnitPrice { get; set; }
        public String formattedTotalPrice { get; set; }
        public String formattedStartDate { get; set; }
        public String formattedEndDate { get; set; }

        public QuoteLineItemWrapper(QuoteLineItem qli) {
            this.item = qli;
            this.formattedUnitPrice = formatCurrency(qli.UnitPrice);
            this.formattedTotalPrice = formatCurrency(qli.TotalPrice);
            this.formattedStartDate = formatDate(qli.StartDate__c);
            this.formattedEndDate = formatDate(qli.EndDate__c);
        }
    }

    public String savePDF(String language) {
        try {
            // Retrieve the Quote record using the instance variable
            Quote quote = [SELECT Id, Name FROM Quote WHERE Id = :this.quote.Id LIMIT 1];

            Blob pdfBlob;
            if (Test.isRunningTest()) {
                // Mock the PDF content for test context
                pdfBlob = Blob.valueOf('Test PDF Content');
            } else {
                // Generate the PDF content from the Visualforce page
                PageReference pdfPage = language == 'DE' ? Page.Angebot_DE : Page.Angebot_EN;
                pdfPage.getParameters().put('id', quote.Id);
                pdfBlob = pdfPage.getContentAsPDF();
            }

            // Create a new File (ContentVersion) record
            ContentVersion file = new ContentVersion();
            file.Title = 'Quote_' + quote.Name + '.pdf';
            file.PathOnClient = 'Quote_' + quote.Name + '.pdf';
            file.VersionData = pdfBlob;
            insert file;

            // Get the ContentDocumentId from the ContentVersion
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :file.Id LIMIT 1].ContentDocumentId;
            cdl.LinkedEntityId = quote.Id;
            cdl.ShareType = 'V';  // Viewer permission
            cdl.Visibility = 'AllUsers';
            insert cdl;

            return cdl.id;
        } catch (Exception e) {
            // Log the error
            System.debug('Error saving PDF: ' + e.getMessage());
            return 'ERROR: ' + e.getMessage();
        }
    }

    // Centralized currency formatting method
    // VF can format currencies out of the box, but only in american format with "," for deicmals and "." for thousands
    // Changing the user locale and also trying to add a custom currency formatting in VF did not help, so I created getter methods that format each currency as a string
    public static String formatCurrency(Decimal inputDecimal) {
        if (inputDecimal == null) {
            return '0,00'; // Default value if null
        }
        
        // Ensure the decimal is rounded to 2 decimal places
        String formattedString = String.valueOf(inputDecimal.setScale(2));
        
        // Split the formatted string into the integer and decimal parts
        List<String> parts = formattedString.split('\\.');
        String integerPart = parts[0];
        String decimalPart = parts.size() > 1 ? parts[1] : '00';
        
        // Add thousands separators (.) for the integer part
        String result = '';
        Integer counter = 0;
        
        for (Integer i = integerPart.length() - 1; i >= 0; i--) {
            result = integerPart.substring(i, i + 1) + result;
            counter++;
            if (counter == 3 && i != 0) {
                result = '.' + result;
                counter = 0;
            }
        }
        
        // Combine the integer part with the decimal part, replacing the decimal separator with a comma
        result = result + ',' + decimalPart;
        
        return result;
    }     

    // Getter for Quote Total Price
    public String getFormattedQuoteTotalPrice() {
        return formatCurrency(quote.TotalPrice);
    }

    // Getter for Shipping Cost Net
    public String getFormattedShippingCostNet() {
        return formatCurrency(quote.ShippingCostNet__c);
    }

    // Getter for Quote Tax
    public String getFormattedQuoteTax() {
        return formatCurrency(quote.Tax);
    }

    // Getter for Shipping Handling
    public String getFormattedShippingHandling() {
        return formatCurrency(quote.ShippingHandling);
    }

    // Getter for Grand Total (Calculated dynamically)
    public String getFormattedGrandTotal() {
        Decimal grandTotal = quote.GrandTotal;
        if (quote.ShippingCostNet__c != null) {
            grandTotal += quote.ShippingCostNet__c;
        }
        return formatCurrency(grandTotal);
    }

    public static String formatDate(Date inputDate) {
        if (inputDate == null) {
            return null;
        }
        // Extract day, month, and year
        String day = inputDate.day() < 10 ? '0' + inputDate.day() : String.valueOf(inputDate.day());
        String month = inputDate.month() < 10 ? '0' + inputDate.month() : String.valueOf(inputDate.month());
        String year = String.valueOf(inputDate.year());
        
        // Combine into DD-MM-YYYY format
        return day + '-' + month + '-' + year;
    }    
}