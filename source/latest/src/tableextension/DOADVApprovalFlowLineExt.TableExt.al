namespace latest.latest;

tableextension 63030 "DOADV Approval Flow Line Ext" extends "CDC Approval Flow Line"
{
    fields
    {
        field(63030; "Notify User"; Boolean)
        {
            Caption = 'Notify User';
            DataClassification = CustomerContent;
        }
    }
}
