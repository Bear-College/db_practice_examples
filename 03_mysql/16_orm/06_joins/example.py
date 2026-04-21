"""
JOIN — Core/ORM style joins (inner and outer).

Run: python example.py
"""
from __future__ import annotations

from sqlalchemy import ForeignKey, String, create_engine, select
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship, Session, joinedload


class Base(DeclarativeBase):
    pass


class Department(Base):
    __tablename__ = "departments"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(80))
    employees: Mapped[list["Employee"]] = relationship(back_populates="dept")


class Employee(Base):
    __tablename__ = "employees"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(80))
    dept_id: Mapped[int | None] = mapped_column(ForeignKey("departments.id"), nullable=True)
    dept: Mapped[Department | None] = relationship(back_populates="employees")


def main() -> None:
    engine = create_engine("sqlite:///06_joins_lab.db", echo=False)
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        d = Department(name="Service")
        session.add_all(
            [
                Employee(name="Ann", dept=d),
                Employee(name="Bob", dept=d),
                Employee(name="Temp", dept=None),
            ]
        )
        session.commit()

    # SQLAlchemy Core / ORM: explicit JOIN
    with Session(engine) as session:
        stmt = (
            select(Employee.name, Department.name)
            .join(Department, Employee.dept_id == Department.id)
            .order_by(Employee.name)
        )
        print("INNER JOIN:", session.execute(stmt).all())

        stmt_left = (
            select(Employee.name, Department.name)
            .outerjoin(Department, Employee.dept_id == Department.id)
            .order_by(Employee.name)
        )
        print("LEFT OUTER JOIN:", session.execute(stmt_left).all())

    # ORM: joinedload (JOIN in SQL to eager-load relationship)
    with Session(engine) as session:
        emps = session.scalars(select(Employee).options(joinedload(Employee.dept))).unique().all()
        print("joinedload:", [(e.name, e.dept.name if e.dept else None) for e in emps])


if __name__ == "__main__":
    main()
