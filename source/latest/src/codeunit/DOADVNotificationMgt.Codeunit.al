namespace latest.latest;
using System.Automation;
using Microsoft.Purchases.Document;

codeunit 63030 "DOADV Notification Mgt"
{
    /// <summary>
    /// Event subscriber that starts the mail notification process
    /// </summary>
    /// <param name="ApprovalEntry"></param>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Approvals Mgmt.", OnApproveApprovalRequest, '', false, false)]
    local procedure ApprovalsMgt_OnApproveApprovalRequest(var ApprovalEntry: Record "Approval Entry")
    begin
        NotifyApprovalFlowMembers(ApprovalEntry);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDO Events", OnGetRecipients, '', false, false)]
    local procedure CDOEvents_OnGetRecipients(var EMailTemplateHeader: Record "CDO E-Mail Template Header"; var Recipients: Text; VAR Cc: Text; VAR Bcc: Text; VAR FilterRecord: RecordRef)
    var
        ApprovalEntry: Record "Approval Entry";
        CDCDocument: Record "CDC Document";
        PurchaseHeader: Record "Purchase Header";
        ApprovalFlowLine: Record "CDC Approval Flow Line";
        ContiniaUser: Record "CDC Continia User";
        CDCPurchDocMgt: Codeunit "CDC Purch. Doc. - Management";
    begin
        ApprovalEntry.Get(FilterRecord.RecordId);

        if not GetPurchaseHeaderFromApprovalEntry(ApprovalEntry, PurchaseHeader, PurchaseHeader."Document Type"::Invoice) then
            exit;

        if not CDCPurchDocMgt.GetPurchaseDocument(PurchaseHeader, CDCDocument) then
            exit;

        if not GetNotificationReceivers(PurchaseHeader, ApprovalFlowLine) then
            exit;

        if ApprovalFlowLine.FindFirst() then
            repeat
                if ContiniaUser.Get(ApprovalFlowLine."Approver ID") then begin
                    if ContiniaUser."E-Mail" <> '' then begin
                        if StrLen(Recipients) > 0 then
                            Recipients += ';';
                        Recipients += ContiniaUser."E-Mail";
                    end;
                end;
            until ApprovalFlowLine.next = 0;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDO Events", OnAttachFilesToMail, '', false, false)]
    local procedure CDOEvents_OnAttachFilesToMail(var EMailTemplateLine: Record 6175284; var DOFile: Record "CDO File"; var FilterRecord: RecordRef; VAR VariantRecord: Variant; SMTP: Boolean)
    var
        CDCDocument: Record "CDC Document";
        PurchaseHeader: Record "Purchase Header";
        ApprovalEntry: Record "Approval Entry";
        TempFile: Record "CDC Temp File" temporary;
        CDCPurchDocMgt: Codeunit "CDC Purch. Doc. - Management";
    begin
        ApprovalEntry.Get(FilterRecord.RecordId);

        if not GetPurchaseHeaderFromApprovalEntry(ApprovalEntry, PurchaseHeader, PurchaseHeader."Document Type"::Invoice) then
            exit;

        if not CDCPurchDocMgt.GetPurchaseDocument(PurchaseHeader, CDCDocument) then
            exit;

        if not CDCDocument.GetPdfFile(TempFile) then
            exit;

        DOFile.Init();
        DOFile.Insert(true);
        DOFile."File Blob" := TempFile.Data;
        DOFile.Filename := TempFile.Name;
        DOFile."File type" := 'pdf';
        DOFile.Modify();
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDO Events", 'OnMergeFieldFind', '', false, false)]
    local procedure CDOEvents_OnMergeFieldFind(var EMailTemplateMergeField: Record "CDO E-Mail Template MergeField"; var FilterRecord: RecordRef; FirstMailToContactNo: Code[20]; var Value: Text)
    var
        ApprovalEntry: Record "Approval Entry";
        ContiniaUser: Record "CDC Continia User";
    begin
        if FilterRecord.Number <> Database::"Approval Entry" then
            exit;

        if not ApprovalEntry.Get(FilterRecord.RecordId) then
            exit;

        case EMailTemplateMergeField.Number of
            // Get the approvers name
            11:
                begin
                    if ContiniaUser.Get(ApprovalEntry."Approver ID") then
                        Value := ContiniaUser.Name;
                end;
            12:
                begin
                    if ContiniaUser.Get(ApprovalEntry."Approver ID") then
                        Value := ContiniaUser."E-Mail";
                end;
        end;
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeSendApprovalNotification(ApprovalEntry: Record "Approval Entry"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterNotifyApprovalFlowMembers(var ApprovalEntry: Record "Approval Entry")
    begin
    end;

    local procedure NotifyApprovalFlowMembers(var ApprovalEntry: Record "Approval Entry")
    var
        PurchaseHeader: Record "Purchase Header";
        ApprovalFlowLines: Record "CDC Approval Flow Line";

    begin
        // Exit if approval status <> approved
        if ApprovalEntry.Status <> ApprovalEntry.Status::Approved then
            exit;

        // Exit if not purchase invoice
        if ApprovalEntry."Document Type" <> "Approval Document Type"::Invoice then
            exit;

        // Exit if PI cannot be found
        if not GetPurchaseHeaderFromApprovalEntry(ApprovalEntry, PurchaseHeader, PurchaseHeader."Document Type"::Invoice) then
            exit;

        // Exit if PI has no approval flow code
        if not GetNotificationReceivers(PurchaseHeader, ApprovalFlowLines) then
            exit;


        SendApprovalNotification(ApprovalEntry);

        OnAfterNotifyApprovalFlowMembers(ApprovalEntry);
    end;



    local procedure GetPurchaseHeaderFromApprovalEntry(ApprovalEntry: Record "Approval Entry"; var PurchaseHeader: Record "Purchase Header"; PurchHeaderType: enum Microsoft.Purchases.Document."Purchase Document Type"): Boolean
    begin
        exit(PurchaseHeader.Get(PurchHeaderType, ApprovalEntry."Document No."));
    end;

    local procedure SendApprovalNotification(ApprovalEntry: Record "Approval Entry")
    var
        EmailTemplateLine: Record "CDO E-Mail Template Line";
        IsHandled: Boolean;
        FilterRecRef: RecordRef;
        VariantRecord: Variant;
    begin
        OnBeforeSendApprovalNotification(ApprovalEntry, IsHandled);
        if IsHandled then
            exit;

        if not FindOutputTemplate(EmailTemplateLine) then
            exit
        else begin
            ApprovalEntry.SetRecFilter();
            FilterRecRef.GetTable(ApprovalEntry);
            VariantRecord := ApprovalEntry;
            EmailTemplateLine.QueueMail(FilterRecRef, VariantRecord, 0, 0);
        end;
    end;

    local procedure FindOutputTemplate(var EmailTemplateLine: Record "CDO E-Mail Template Line"): Boolean
    begin
        EmailTemplateLine.SetRange("First Table in Report", Database::"Approval Entry");
        EmailTemplateLine.SetRange(Enabled, true);
        if EmailTemplateLine.IsEmpty then
            exit;

        exit(EmailTemplateLine.FindFirst());

    end;

    local procedure GetNotificationReceivers(PurchaseHeader: Record "Purchase Header"; var ApprovalFlowLines: Record "CDC Approval Flow Line"): Boolean
    var
        CDCPurchHeaderInfo: Record "CDC Purchase Header Info.";
        CDCApprovalFlowCode: Code[10];
    begin
        CDCApprovalFlowCode := CDCPurchHeaderInfo.GetApprovalFlowCode(PurchaseHeader);
        if CDCApprovalFlowCode = '' then
            exit;

        ApprovalFlowLines.SetRange("Approval Flow Code", CDCApprovalFlowCode);
        ApprovalFlowLines.SetRange("Notify User", true);

        //TODO Activate later ApprovalFlowLines.SetFilter("Approver ID", '<>%1', UserId);
        exit(not ApprovalFlowLines.IsEmpty);
    end;
}
